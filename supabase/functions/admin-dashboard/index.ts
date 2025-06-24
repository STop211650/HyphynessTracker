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

    // Get dashboard data
    const { data: dashboard, error: dashboardError } = await supabase
      .from('v_admin_dashboard')
      .select('*')
      .single()

    if (dashboardError) {
      throw new Error(`Failed to get dashboard data: ${dashboardError.message}`)
    }

    // Get recent activity
    const { data: recentBets, error: betsError } = await supabase
      .from('bets')
      .select(`
        id,
        ticket_number,
        type,
        status,
        risk,
        to_win,
        placed_at,
        users!bets_created_by_fkey(name)
      `)
      .order('placed_at', { ascending: false })
      .limit(10)

    if (betsError) {
      console.error('Error fetching recent bets:', betsError)
    }

    const { data: recentPayments, error: paymentsError } = await supabase
      .from('payments')
      .select(`
        id,
        amount,
        payment_method,
        paid_at,
        from_user:users!payments_from_user_id_fkey(name),
        to_user:users!payments_to_user_id_fkey(name)
      `)
      .order('paid_at', { ascending: false })
      .limit(10)

    if (paymentsError) {
      console.error('Error fetching recent payments:', paymentsError)
    }

    // Get user balances
    const { data: userBalances, error: balancesError } = await supabase
      .from('v_user_balance')
      .select('*')
      .order('outstanding_balance', { ascending: false })

    if (balancesError) {
      console.error('Error fetching user balances:', balancesError)
    }

    // Get pending invites
    const { data: pendingInvites, error: invitesError } = await supabase
      .from('admin_invites')
      .select(`
        id,
        email,
        name,
        expires_at,
        created_at,
        created_by_user:users!admin_invites_created_by_fkey(name)
      `)
      .is('used_at', null)
      .gt('expires_at', new Date().toISOString())
      .order('created_at', { ascending: false })

    if (invitesError) {
      console.error('Error fetching pending invites:', invitesError)
    }

    return new Response(
      JSON.stringify({
        success: true,
        dashboard: {
          stats: dashboard,
          recent_bets: recentBets || [],
          recent_payments: recentPayments || [],
          user_balances: userBalances || [],
          pending_invites: pendingInvites || []
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in admin-dashboard function:', error)
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