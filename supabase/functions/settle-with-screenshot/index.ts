// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'
import { parseBetScreenshot } from '../_shared/vision.ts'
import { BetData } from '../_shared/types.ts'

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body = await req.json()
    const { screenshot, bet_id } = body

    if (!screenshot || !bet_id) {
      throw new Error('Missing required fields: screenshot, bet_id')
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

    // Parse the settlement screenshot
    console.log('Parsing settlement screenshot...')
    const parsedData = await parseBetScreenshot(screenshot)
    console.log('Parsed settlement data:', JSON.stringify(parsedData, null, 2))

    // Verify it's a settled bet
    if (!parsedData.status || parsedData.status === 'pending') {
      throw new Error('Screenshot does not show a settled bet')
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

    // Verify ticket number match if available
    if (parsedData.ticket_number && bet.ticket_number && 
        parsedData.ticket_number !== bet.ticket_number) {
      throw new Error('Ticket number mismatch. This screenshot does not match the selected bet.')
    }

    // Update bet status with screenshot proof
    const { data: updatedBet, error: updateError } = await supabase
      .from('bets')
      .update({
        status: parsedData.status,
        settled_at: new Date().toISOString(),
        settlement_screenshot: screenshot // Store proof
      })
      .eq('id', bet.id)
      .select('*')
      .single()

    if (updateError) {
      throw new Error(`Failed to update bet: ${updateError.message}`)
    }

    // Separately fetch participants with user details
    const { data: participants, error: participantsError } = await supabase
      .from('bet_participants')
      .select(`
        user_id,
        stake,
        payout_due,
        user:users!bet_participants_user_id_fkey (
          name
        )
      `)
      .eq('bet_id', bet.id)

    if (participantsError) {
      throw new Error(`Failed to fetch participants: ${participantsError.message}`)
    }

    // Attach participants to the bet object
    updatedBet.bet_participants = participants

    // Calculate summary
    const totalPayout = updatedBet.bet_participants.reduce(
      (sum: number, p: any) => sum + (p.payout_due || 0), 
      0
    )

    const winners = updatedBet.bet_participants
      .filter((p: any) => p.payout_due > p.stake)
      .map((p: any) => ({
        name: p.user?.name || 'Unknown',
        profit: p.payout_due - p.stake
      }))

    const losers = updatedBet.bet_participants
      .filter((p: any) => p.payout_due < p.stake)
      .map((p: any) => ({
        name: p.user?.name || 'Unknown',
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
    console.error('Error in settle-with-screenshot function:', error)
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