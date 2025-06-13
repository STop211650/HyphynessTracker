import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'

serve(async (req) => {
  // Handle CORS
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

    // Get query parameters for filtering
    const url = new URL(req.url)
    const startDate = url.searchParams.get('start_date')
    const endDate = url.searchParams.get('end_date')
    const status = url.searchParams.get('status') // pending, won, lost, void, push
    const exportType = url.searchParams.get('type') || 'bets' // bets, payments, or ledger

    if (exportType === 'bets') {
      // Export bets data
      let query = supabase
        .from('bets')
        .select(`
          ticket_number,
          sportsbook,
          type,
          status,
          risk,
          to_win,
          payout_total,
          odds,
          placed_at,
          settled_at,
          bet_participants (
            stake,
            payout_due,
            is_paid,
            users (name)
          ),
          bet_legs (
            event,
            market,
            selection,
            odds
          )
        `)
        .or(`created_by.eq.${user.id},bet_participants.user_id.eq.${user.id}`)

      // Apply filters
      if (startDate) {
        query = query.gte('placed_at', startDate)
      }
      if (endDate) {
        query = query.lte('placed_at', endDate)
      }
      if (status) {
        query = query.eq('status', status)
      }

      const { data: bets, error } = await query

      if (error) {
        throw new Error(`Failed to fetch bets: ${error.message}`)
      }

      // Convert to CSV
      const csvRows = ['Ticket Number,Sportsbook,Type,Status,Risk,To Win,Payout,Odds,Placed At,Settled At,Participants,Stakes,Payouts,Event Details']
      
      for (const bet of bets || []) {
        const participants = bet.bet_participants.map((p: any) => p.users.name).join(';')
        const stakes = bet.bet_participants.map((p: any) => p.stake).join(';')
        const payouts = bet.bet_participants.map((p: any) => p.payout_due).join(';')
        const events = bet.bet_legs.map((l: any) => `${l.event} ${l.market} ${l.selection} ${l.odds}`).join(';')
        
        csvRows.push([
          bet.ticket_number,
          bet.sportsbook || '',
          bet.type,
          bet.status,
          bet.risk,
          bet.to_win,
          bet.payout_total || 0,
          bet.odds,
          bet.placed_at,
          bet.settled_at || '',
          participants,
          stakes,
          payouts,
          events
        ].map(field => `"${field}"`).join(','))
      }

      const csvContent = csvRows.join('\n')
      
      return new Response(csvContent, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="bets_export_${new Date().toISOString().split('T')[0]}.csv"`
        }
      })

    } else if (exportType === 'payments') {
      // Export payments data
      let query = supabase
        .from('payments')
        .select(`
          amount,
          payment_method,
          note,
          paid_at,
          from_user:users!payments_from_user_id_fkey(name),
          to_user:users!payments_to_user_id_fkey(name),
          bets(ticket_number, status)
        `)
        .or(`from_user_id.eq.${user.id},to_user_id.eq.${user.id}`)

      if (startDate) {
        query = query.gte('paid_at', startDate)
      }
      if (endDate) {
        query = query.lte('paid_at', endDate)
      }

      const { data: payments, error } = await query

      if (error) {
        throw new Error(`Failed to fetch payments: ${error.message}`)
      }

      // Convert to CSV
      const csvRows = ['From User,To User,Amount,Payment Method,Note,Paid At,Bet Ticket,Bet Status']
      
      for (const payment of payments || []) {
        csvRows.push([
          payment.from_user.name,
          payment.to_user.name,
          payment.amount,
          payment.payment_method || '',
          payment.note || '',
          payment.paid_at,
          payment.bets.ticket_number,
          payment.bets.status
        ].map(field => `"${field}"`).join(','))
      }

      const csvContent = csvRows.join('\n')
      
      return new Response(csvContent, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="payments_export_${new Date().toISOString().split('T')[0]}.csv"`
        }
      })

    } else if (exportType === 'ledger') {
      // Export user ledger summary
      const { data: ledger, error } = await supabase
        .from('v_user_ledger')
        .select('*')
        .eq('user_id', user.id)

      if (error) {
        throw new Error(`Failed to fetch ledger: ${error.message}`)
      }

      // Convert to CSV
      const csvRows = ['User Name,Bet Ticket,Placed At,Status,Stake,Payout Due,Is Paid,Profit/Loss']
      
      for (const entry of ledger || []) {
        csvRows.push([
          entry.user_name,
          entry.ticket_number,
          entry.placed_at,
          entry.status,
          entry.stake,
          entry.payout_due,
          entry.is_paid ? 'Yes' : 'No',
          entry.profit_loss
        ].map(field => `"${field}"`).join(','))
      }

      const csvContent = csvRows.join('\n')
      
      return new Response(csvContent, {
        headers: {
          ...corsHeaders,
          'Content-Type': 'text/csv',
          'Content-Disposition': `attachment; filename="ledger_export_${new Date().toISOString().split('T')[0]}.csv"`
        }
      })

    } else {
      throw new Error('Invalid export type. Must be: bets, payments, or ledger')
    }

  } catch (error) {
    console.error('Error in export-csv function:', error)
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