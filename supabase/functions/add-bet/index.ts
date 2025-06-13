import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabase, getOrCreateParticipant } from '../_shared/supabase.ts'
import { parseBetScreenshot } from '../_shared/vision.ts'
import { parseParticipants, validateStakes } from '../_shared/participants.ts'
import { AddBetRequest } from '../_shared/types.ts'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: AddBetRequest = await req.json()
    const { screenshot, participants_text } = body

    if (!screenshot || !participants_text) {
      throw new Error('Missing required fields: screenshot and participants_text')
    }

    // Get authenticated user (bet creator)
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

    // Parse bet data from screenshot
    console.log('Parsing bet screenshot...')
    const betData = await parseBetScreenshot(screenshot)

    // Parse participants
    console.log('Parsing participants...')
    const participants = parseParticipants(participants_text)
    
    if (participants.length === 0) {
      throw new Error('No valid participants found in text')
    }

    // Validate stakes sum to risk
    if (!validateStakes(participants, betData.risk)) {
      throw new Error(`Stakes must sum to bet risk amount ($${betData.risk})`)
    }

    // Get or create participant users
    const participantUsers = []
    for (const participant of participants) {
      const { data: participantUser, error } = await getOrCreateParticipant(participant.name)
      if (error) {
        throw new Error(`Failed to create participant ${participant.name}: ${error.message}`)
      }
      participantUsers.push({
        user: participantUser,
        stake: participant.stake
      })
    }

    // Start transaction to create bet and related records
    const { data: bet, error: betError } = await supabase
      .from('bets')
      .insert([{
        ticket_number: betData.ticket_number,
        sportsbook: betData.sportsbook,
        type: betData.type,
        status: betData.status,
        risk: betData.risk,
        to_win: betData.to_win,
        odds: betData.odds,
        created_by: user.id,
        screenshot_url: screenshot // In production, upload to storage first
      }])
      .select()
      .single()

    if (betError) {
      throw new Error(`Failed to create bet: ${betError.message}`)
    }

    // Create bet legs for parlays
    if (betData.legs.length > 0) {
      const legs = betData.legs.map(leg => ({
        bet_id: bet.id,
        event: leg.event,
        market: leg.market,
        selection: leg.selection,
        odds: leg.odds
      }))

      const { error: legsError } = await supabase
        .from('bet_legs')
        .insert(legs)

      if (legsError) {
        throw new Error(`Failed to create bet legs: ${legsError.message}`)
      }
    }

    // Create bet participants
    const betParticipants = participantUsers.map(({ user, stake }) => ({
      bet_id: bet.id,
      user_id: user.id,
      stake: stake,
      payout_due: 0, // Will be calculated when bet settles
      is_paid: false
    }))

    const { error: participantsError } = await supabase
      .from('bet_participants')
      .insert(betParticipants)

    if (participantsError) {
      throw new Error(`Failed to create participants: ${participantsError.message}`)
    }

    // Return success with bet details
    return new Response(
      JSON.stringify({
        success: true,
        bet: {
          id: bet.id,
          ticket_number: bet.ticket_number,
          type: bet.type,
          risk: bet.risk,
          to_win: bet.to_win,
          participants: participants
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in add-bet function:', error)
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