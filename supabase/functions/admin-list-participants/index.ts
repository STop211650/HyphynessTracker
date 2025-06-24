import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'

serve(async (req) => {
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

    // Get all users with their participation stats
    const { data: participants, error: participantsError } = await supabase
      .from('users')
      .select(`
        id,
        name,
        email,
        is_super_admin,
        created_at,
        bet_participants (
          bet_id,
          stake,
          payout_due,
          is_paid,
          bets (
            status,
            placed_at
          )
        )
      `)
      .order('created_at', { ascending: true })

    if (participantsError) {
      throw new Error(`Failed to fetch participants: ${participantsError.message}`)
    }

    // Process participant data
    const processedParticipants = participants.map(participant => {
      const isPlaceholder = participant.email.includes('@pending.hyphyness')
      const betCount = participant.bet_participants.length
      const totalStaked = participant.bet_participants.reduce((sum, bp) => sum + (bp.stake || 0), 0)
      const totalPayout = participant.bet_participants.reduce((sum, bp) => sum + (bp.payout_due || 0), 0)
      const pendingBets = participant.bet_participants.filter(bp => bp.bets.status === 'pending').length
      const unpaidWinnings = participant.bet_participants
        .filter(bp => !bp.is_paid && bp.payout_due > bp.stake)
        .reduce((sum, bp) => sum + (bp.payout_due - bp.stake), 0)

      return {
        id: participant.id,
        name: participant.name,
        email: participant.email,
        is_placeholder: isPlaceholder,
        is_super_admin: participant.is_super_admin,
        created_at: participant.created_at,
        stats: {
          total_bets: betCount,
          total_staked: totalStaked,
          total_payout: totalPayout,
          pending_bets: pendingBets,
          net_position: totalPayout - totalStaked,
          unpaid_winnings: unpaidWinnings
        }
      }
    })

    // Separate into categories
    const placeholders = processedParticipants.filter(p => p.is_placeholder)
    const realUsers = processedParticipants.filter(p => !p.is_placeholder)
    const admins = processedParticipants.filter(p => p.is_super_admin)

    return new Response(
      JSON.stringify({
        success: true,
        summary: {
          total_participants: processedParticipants.length,
          placeholder_users: placeholders.length,
          real_users: realUsers.length,
          super_admins: admins.length
        },
        participants: {
          all: processedParticipants,
          placeholders: placeholders,
          real_users: realUsers,
          admins: admins
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in admin-list-participants function:', error)
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