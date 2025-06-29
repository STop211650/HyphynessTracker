// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'
// Removed unused imports

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body = await req.json()
    const { bet_id, status } = body

    if (!bet_id || !status) {
      throw new Error('Missing required fields: bet_id, status')
    }
    
    // Validate status
    if (!['won', 'lost', 'void', 'push'].includes(status)) {
      throw new Error('Invalid status. Must be: won, lost, void, or push')
    }

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

    // Find the bet by ID
    const { data: bet, error: betError } = await supabase
      .from('bets')
      .select('*')
      .eq('id', bet_id)
      .single()

    if (betError || !bet) {
      throw new Error(`Bet not found with ID: ${bet_id}`)
    }

    // Check if user has permission to settle this bet
    if (bet.created_by !== user.id) {
      // Check if user is a participant
      const { data: participant } = await supabase
        .from('bet_participants')
        .select('user_id')
        .eq('bet_id', bet.id)
        .eq('user_id', user.id)
        .single()

      if (!participant) {
        throw new Error('You do not have permission to settle this bet')
      }
    }

    // Check if bet is already settled
    if (bet.status !== 'pending') {
      throw new Error(`Bet is already settled with status: ${bet.status}`)
    }

    // Update bet status (trigger will handle payout calculations)
    const { data: updatedBet, error: updateError } = await supabase
      .from('bets')
      .update({
        status: status,
        settled_at: new Date().toISOString()
      })
      .eq('id', bet.id)
      .select(`
        *,
        bet_participants (
          user_id,
          stake,
          payout_due,
          users (
            name
          )
        )
      `)
      .single()

    if (updateError) {
      throw new Error(`Failed to update bet: ${updateError.message}`)
    }

    // Calculate summary
    const totalPayout = updatedBet.bet_participants.reduce(
      (sum: number, p: any) => sum + (p.payout_due || 0), 
      0
    )

    const winners = updatedBet.bet_participants
      .filter((p: any) => p.payout_due > p.stake)
      .map((p: any) => ({
        name: p.users.name,
        profit: p.payout_due - p.stake
      }))

    const losers = updatedBet.bet_participants
      .filter((p: any) => p.payout_due < p.stake)
      .map((p: any) => ({
        name: p.users.name,
        loss: p.stake - p.payout_due
      }))

    // Return success with settlement details
    return new Response(
      JSON.stringify({
        success: true,
        settlement: {
          bet_id: updatedBet.id,
          ticket_number: updatedBet.ticket_number,
          status: updatedBet.status,
          risk: updatedBet.risk,
          total_payout: totalPayout,
          winners,
          losers
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in settle-bet function:', error)
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