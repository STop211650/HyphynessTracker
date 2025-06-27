// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase, getOrCreateParticipant } from '../_shared/supabase.ts'
import { parseBetScreenshot } from '../_shared/vision.ts'
import { parseParticipants, validateStakes } from '../_shared/participants.ts'
import { AddBetRequest } from '../_shared/types.ts'

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body = await req.json()
    const { screenshot, participants_text, who_paid, bet_data_override } = body

    if (!screenshot || !participants_text) {
      throw new Error('Missing required fields: screenshot and participants_text')
    }

    // Get authenticated user (bet creator)
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )

    if (authError || !authUser) {
      throw new Error('Unauthorized')
    }

    // Get bet data - either from override or by parsing screenshot
    let betData
    if (bet_data_override) {
      console.log('Using override bet data from client...')
      betData = bet_data_override
    } else {
      console.log('Parsing bet screenshot...')
      betData = await parseBetScreenshot(screenshot)
    }
    console.log('Bet data:', JSON.stringify(betData, null, 2))
    
    // Validate and normalize odds format
    if (betData.odds) {
      // Check if odds are in incorrect format (e.g., "-$100/$290")
      if (betData.odds.includes('$') || betData.odds.includes('/')) {
        console.log(`Invalid odds format detected: ${betData.odds}`)
        // Calculate correct odds from risk/to_win
        if (betData.risk && betData.to_win) {
          const ratio = betData.to_win / betData.risk
          if (ratio > 1) {
            betData.odds = `+${Math.round(ratio * 100)}`
          } else if (ratio < 1) {
            betData.odds = `-${Math.round(100 / ratio)}`
          } else {
            betData.odds = '+100'
          }
          console.log(`Corrected odds to: ${betData.odds}`)
        }
      }
      // Ensure odds start with + or -
      else if (!betData.odds.startsWith('+') && !betData.odds.startsWith('-')) {
        betData.odds = `+${betData.odds}`
        console.log(`Added + prefix to odds: ${betData.odds}`)
      }
    }
    
    // Normalize status to valid values
    const validStatuses = ['pending', 'won', 'lost', 'void', 'push']
    const statusLower = betData.status.toLowerCase()
    
    if (statusLower.includes('win') || statusLower.includes('won')) {
      betData.status = 'won'
    } else if (statusLower.includes('loss') || statusLower.includes('lost')) {
      betData.status = 'lost'
    } else if (statusLower.includes('void')) {
      betData.status = 'void'
    } else if (statusLower.includes('push')) {
      betData.status = 'push'
    } else if (!validStatuses.includes(betData.status)) {
      console.log(`Invalid status "${betData.status}", defaulting to "pending"`)
      betData.status = 'pending'
    }
    
    // Normalize bet type to valid values
    const validTypes = ['straight', 'parlay', 'teaser', 'round_robin', 'futures']
    const typeLower = betData.type.toLowerCase()
    
    if (typeLower.includes('single') || typeLower.includes('straight')) {
      betData.type = 'straight'
    } else if (typeLower.includes('parlay')) {
      betData.type = 'parlay'
    } else if (typeLower.includes('teaser')) {
      betData.type = 'teaser'
    } else if (typeLower.includes('round') || typeLower.includes('robin')) {
      betData.type = 'round_robin'
    } else if (typeLower.includes('future')) {
      betData.type = 'futures'
    } else if (!validTypes.includes(betData.type)) {
      console.log(`Invalid type "${betData.type}", defaulting to "straight"`)
      betData.type = 'straight'
    }

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
        created_by: authUser.id,
        screenshot_url: screenshot, // In production, upload to storage first
        settled_at: betData.status !== 'pending' ? new Date().toISOString() : null
      }])
      .select()
      .single()

    if (betError) {
      // Check for duplicate ticket number (unique constraint violation)
      if (betError.code === '23505') {
        return new Response(
          JSON.stringify({
            success: false,
            error: `A bet with ticket number ${betData.ticket_number} already exists`,
            isDuplicate: true,
            ticket_number: betData.ticket_number
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 409
          }
        )
      }
      throw new Error(`Failed to create bet: ${betError.message}`)
    }

    // Create bet legs for parlays
    if (betData.legs && betData.legs.length > 0) {
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

    // Determine who paid for the bet
    let payerUserId = authUser.id // Default to authenticated user
    
    if (who_paid) {
      // Find the user who paid by name
      const { data: payerUser, error: payerError } = await getOrCreateParticipant(who_paid)
      if (payerError) {
        throw new Error(`Failed to find payer ${who_paid}: ${payerError.message}`)
      }
      payerUserId = payerUser.id
    }

    // Create bet participants
    // Logic: Use specified payer, or default to authenticated user for multiple participants
    const betParticipants = participantUsers.map(({ user, stake }) => {
      // Calculate payout_due for won bets
      let payoutDue = 0
      if (bet.status === 'won') {
        // Calculate proportional winnings
        const stakeRatio = stake / bet.risk
        payoutDue = bet.to_win * stakeRatio
      }
      
      return {
        bet_id: bet.id,
        user_id: user.id,
        stake: stake,
        payout_due: payoutDue,
        is_paid: false,
        who_paid_for: participants.length > 1 ? payerUserId : user.id // If multiple participants: use specified payer, if single: they paid for themselves
      }
    })

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