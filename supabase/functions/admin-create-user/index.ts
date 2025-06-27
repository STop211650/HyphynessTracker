// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'

interface CreateUserRequest {
  email: string
  name: string
  password?: string
  invite_token?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const body: CreateUserRequest = await req.json()
    const { email, name, password, invite_token } = body

    if (!email || !name) {
      throw new Error('Email and name are required')
    }

    // If invite token provided, validate it
    if (invite_token) {
      const { data: invite, error: inviteError } = await supabase
        .from('admin_invites')
        .select('*')
        .eq('token', invite_token)
        .eq('email', email)
        .is('used_at', null)
        .gt('expires_at', new Date().toISOString())
        .single()

      if (inviteError || !invite) {
        throw new Error('Invalid or expired invite token')
      }

      // Mark invite as used
      await supabase
        .from('admin_invites')
        .update({ used_at: new Date().toISOString() })
        .eq('id', invite.id)
    } else {
      // Check if request is from super admin
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        throw new Error('Missing authorization or invite token')
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
    }

    // Generate password if not provided
    const userPassword = password || crypto.randomUUID().slice(0, 12)

    // Create auth user
    const { data: authUser, error: signUpError } = await supabase.auth.admin.createUser({
      email,
      password: userPassword,
      email_confirm: true
    })

    if (signUpError) {
      throw new Error(`Failed to create auth user: ${signUpError.message}`)
    }

    // Create user in our custom table
    const { data: customUser, error: userError } = await supabase
      .from('users')
      .insert([{
        id: authUser.user.id,
        email,
        name
      }])
      .select()
      .single()

    if (userError) {
      // Clean up auth user if custom user creation fails
      await supabase.auth.admin.deleteUser(authUser.user.id)
      throw new Error(`Failed to create user record: ${userError.message}`)
    }

    return new Response(
      JSON.stringify({
        success: true,
        user: {
          id: customUser.id,
          email: customUser.email,
          name: customUser.name,
          temporary_password: password ? undefined : userPassword
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in admin-create-user function:', error)
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