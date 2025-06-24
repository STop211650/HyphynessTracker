import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'

interface InviteRequest {
  email: string
  name: string
  send_email?: boolean
}

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

    const body: InviteRequest = await req.json()
    const { email, name, send_email = false } = body

    if (!email || !name) {
      throw new Error('Email and name are required')
    }

    // Check if user already exists
    const { data: existingUser } = await supabase
      .from('users')
      .select('id')
      .eq('email', email)
      .single()

    if (existingUser) {
      throw new Error('User with this email already exists')
    }

    // Generate unique invite token
    const token = crypto.randomUUID()

    // Create invite record
    const { data: invite, error: inviteError } = await supabase
      .from('admin_invites')
      .insert([{
        email,
        name,
        token,
        created_by: user.id
      }])
      .select()
      .single()

    if (inviteError) {
      throw new Error(`Failed to create invite: ${inviteError.message}`)
    }

    // TODO: Send email if requested
    if (send_email) {
      console.log(`TODO: Send invite email to ${email} with token ${token}`)
      // In production, integrate with email service like Resend or SendGrid
    }

    return new Response(
      JSON.stringify({
        success: true,
        invite: {
          id: invite.id,
          email: invite.email,
          name: invite.name,
          token: invite.token,
          invite_url: `${Deno.env.get('NEXT_PUBLIC_APP_URL')}/invite/${token}`,
          expires_at: invite.expires_at
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in admin-invite function:', error)
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