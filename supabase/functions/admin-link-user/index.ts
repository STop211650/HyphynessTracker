// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'

interface LinkUserRequest {
  participant_name: string
  new_email: string
  new_password?: string
  create_account?: boolean
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )

    if (authError || !user) {
      throw new Error('Unauthorized')
    }

    // Check if user is super admin
    const { data: adminUser, error: adminError } = await supabase
      .from('users')
      .select('is_super_admin')
      .eq('id', user.id)
      .single()

    if (adminError || !adminUser?.is_super_admin) {
      throw new Error('Super admin access required')
    }

    const body: LinkUserRequest = await req.json()
    const { participant_name, new_email, new_password, create_account = true } = body

    if (!participant_name || !new_email) {
      throw new Error('participant_name and new_email are required')
    }

    // Find existing participant by name
    const { data: existingParticipant, error: participantError } = await supabase
      .from('users')
      .select('*')
      .eq('name', participant_name)
      .single()

    if (participantError || !existingParticipant) {
      throw new Error(`Participant not found: ${participant_name}`)
    }

    // Check if this is a placeholder user (has pending email)
    const isPlaceholder = existingParticipant.email.includes('@pending.hyphyness')
    
    if (!isPlaceholder && existingParticipant.email !== new_email) {
      throw new Error(`Participant ${participant_name} already has a real email: ${existingParticipant.email}`)
    }

    let newAuthUserId = null

    if (create_account) {
      // Create new auth user
      const password = new_password || crypto.randomUUID().slice(0, 12)
      
      const { data: authUser, error: signUpError } = await supabase.auth.admin.createUser({
        email: new_email,
        password: password,
        email_confirm: true
      })

      if (signUpError) {
        throw new Error(`Failed to create auth user: ${signUpError.message}`)
      }

      newAuthUserId = authUser.user.id
      console.log(`Created new auth user: ${new_email} with password: ${password}`)
    } else {
      // User should already exist - find them
      const { data: existingAuthUser, error: authFindError } = await supabase.auth.admin.listUsers()
      
      if (authFindError) {
        throw new Error('Failed to find existing auth users')
      }

      const foundUser = existingAuthUser.users.find(u => u.email === new_email)
      if (!foundUser) {
        throw new Error(`Auth user not found with email: ${new_email}`)
      }

      newAuthUserId = foundUser.id
    }

    // Get bet history for this participant
    const { data: betHistory, error: historyError } = await supabase
      .from('bet_participants')
      .select(`
        bet_id,
        stake,
        payout_due,
        is_paid,
        bets (
          ticket_number,
          type,
          status,
          risk,
          to_win,
          placed_at
        )
      `)
      .eq('user_id', existingParticipant.id)

    if (historyError) {
      console.error('Error fetching bet history:', historyError)
    }

    // Update the participant record with new auth ID and email
    const { data: updatedUser, error: updateError } = await supabase
      .from('users')
      .update({
        id: newAuthUserId,
        email: new_email
      })
      .eq('id', existingParticipant.id)
      .select()
      .single()

    if (updateError) {
      // Clean up auth user if update fails
      if (create_account) {
        await supabase.auth.admin.deleteUser(newAuthUserId)
      }
      throw new Error(`Failed to link user: ${updateError.message}`)
    }

    // Calculate summary stats
    const totalBets = betHistory?.length || 0
    const totalStaked = betHistory?.reduce((sum, b) => sum + (b.stake || 0), 0) || 0
    const totalPayout = betHistory?.reduce((sum, b) => sum + (b.payout_due || 0), 0) || 0
    const pendingBets = betHistory?.filter(b => b.bets.status === 'pending').length || 0

    return new Response(
      JSON.stringify({
        success: true,
        linked_user: {
          id: updatedUser.id,
          name: updatedUser.name,
          email: updatedUser.email,
          was_placeholder: isPlaceholder,
          temporary_password: create_account ? new_password || 'generated' : undefined
        },
        bet_history_summary: {
          total_bets: totalBets,
          total_staked: totalStaked,
          total_payout: totalPayout,
          pending_bets: pendingBets,
          net_position: totalPayout - totalStaked
        },
        message: `Successfully linked ${participant_name} to ${new_email}. All ${totalBets} bet(s) are now associated with their account.`
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in admin-link-user function:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})