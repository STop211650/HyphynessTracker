// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'
import { BetData } from '../_shared/types.ts'

interface MatchRequest {
  bet_data: BetData
  ticket_number?: string
}

interface BetMatch {
  id: string
  confidence: number
  bet_data: any
  created_at: string
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('find-matching-bet: Starting request processing')
    
    // Parse the incoming request body
    // Expected: bet_data (required) - the parsed bet data from the settlement screenshot
    //           ticket_number (optional) - explicit ticket number to search for
    const body: MatchRequest = await req.json()
    console.log('find-matching-bet: Request body:', JSON.stringify(body))
    
    const { bet_data, ticket_number } = body

    if (!bet_data) {
      throw new Error('Missing required field: bet_data')
    }

    // Authenticate the user making the request
    const authHeader = req.headers.get('Authorization')
    console.log('find-matching-bet: Auth header present:', !!authHeader)
    
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const { data: { user: authUser }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    )
    
    console.log('find-matching-bet: Auth result - user:', authUser?.id, 'error:', authError?.message)

    if (authError || !authUser) {
      throw new Error('Unauthorized')
    }

    // Array to store all potential matches with their confidence scores
    const matches: BetMatch[] = []

    // Strategy 1: Exact ticket number match (highest confidence)
    // If we have a ticket number (either provided directly or extracted from the screenshot),
    // search for an exact match. This is the most reliable matching method.
    if (ticket_number || bet_data.ticket_number) {
      const ticketToMatch = ticket_number || bet_data.ticket_number
      console.log('find-matching-bet: Searching for ticket:', ticketToMatch)
      
      // Query the database for pending bets with matching ticket number
      const { data: ticketMatches, error: ticketError } = await supabase
        .from('bets')
        .select('*')
        .eq('created_by', authUser.id)  // Only match user's own bets
        .eq('status', 'pending')         // Only match pending bets (not already settled)
        .eq('ticket_number', ticketToMatch)

      console.log('find-matching-bet: Ticket search result - matches:', ticketMatches?.length, 'error:', ticketError?.message)

      if (!ticketError && ticketMatches && ticketMatches.length > 0) {
        // For each matching bet, also fetch its legs
        for (const bet of ticketMatches) {
          console.log('find-matching-bet: Processing bet:', JSON.stringify(bet))
          
          // Fetch bet legs
          const { data: legs, error: legsError } = await supabase
            .from('bet_legs')
            .select('*')
            .eq('bet_id', bet.id)
          
          const betLegs = !legsError && legs ? legs.map(leg => ({
            event: leg.event,
            market: leg.market,
            selection: leg.selection,
            odds: leg.odds
          })) : []
          
          matches.push({
            id: bet.id,
            confidence: 100,  // 100% confidence for exact ticket match
            bet_data: {
              ticket_number: bet.ticket_number,
              sportsbook: bet.sportsbook || null,
              type: bet.type,
              status: bet.status,
              risk: bet.risk,
              to_win: bet.to_win,
              odds: bet.odds,
              legs: betLegs
            },
            created_at: bet.created_at
          })
        }
      }
    }

    // Strategy 2: Fuzzy matching on multiple attributes
    // If no exact ticket match was found, fall back to fuzzy matching based on bet characteristics
    if (matches.length === 0) {
      // Get all pending bets for the user from the last 30 days
      const thirtyDaysAgo = new Date()
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

      // FIXED: Changed from 'placer_id' to 'created_by' to match the database schema
      // This was causing the query to return no results, preventing bet matching
      const { data: pendingBets, error: pendingError } = await supabase
        .from('bets')
        .select('*')
        .eq('created_by', authUser.id)  // Fixed: was 'placer_id', should be 'created_by'
        .eq('status', 'pending')         // Only match pending bets
        .gte('created_at', thirtyDaysAgo.toISOString())  // Limit to recent bets

      if (!pendingError && pendingBets) {
        // Score each pending bet based on how well it matches the settlement data
        // Total possible score: 100 points distributed across different attributes
        for (const bet of pendingBets) {
          let score = 0

          // Check sportsbook match (20 points)
          // Sportsbook is a strong indicator - bets from different books can't match
          if (bet_data.sportsbook && bet.sportsbook && 
              bet_data.sportsbook.toLowerCase() === bet.sportsbook.toLowerCase()) {
            score += 20
          }

          // Check bet type match (20 points)
          // Type must match (straight, parlay, etc.) for bets to be the same
          if (bet_data.type === bet.type) {
            score += 20
          }

          // Check odds match (20 points)
          // Odds are a unique identifier for the same bet
          if (bet_data.odds === bet.odds) {
            score += 20
          }

          // Check risk amount match with tolerance (25 points - highest weight)
          // Risk amount is the most important factor as it's user-specific
          const riskDiff = Math.abs(bet_data.risk - bet.risk)
          if (riskDiff < 0.01) {
            score += 25  // Exact match (within penny)
          } else if (riskDiff < 1.00) {
            score += 15  // Close match (within dollar)
          }

          // Check to_win amount match with tolerance (15 points)
          // To-win should correlate with risk and odds
          const winDiff = Math.abs(bet_data.to_win - bet.to_win)
          if (winDiff < 0.01) {
            score += 15  // Exact match (within penny)
          } else if (winDiff < 1.00) {
            score += 10  // Close match (within dollar)
          }

          // For parlays, check leg count (10 bonus points)
          // Parlays with different leg counts can't be the same bet
          if (bet_data.type === 'parlay' && bet.type === 'parlay') {
            // Fetch legs for this bet to compare count
            const { data: legs } = await supabase
              .from('bet_legs')
              .select('*')
              .eq('bet_id', bet.id)
            
            if (bet_data.legs?.length === (legs?.length || 0)) {
              score += 10
            }
          }

          // Only include bets with reasonable confidence (60% or higher)
          // This prevents showing unlikely matches that would confuse users
          if (score >= 60) {
            // Fetch bet legs for the response
            const { data: legs, error: legsError } = await supabase
              .from('bet_legs')
              .select('*')
              .eq('bet_id', bet.id)
            
            const betLegs = !legsError && legs ? legs.map(leg => ({
              event: leg.event,
              market: leg.market,
              selection: leg.selection,
              odds: leg.odds
            })) : []
            
            matches.push({
              id: bet.id,
              confidence: score,
              bet_data: {
                ticket_number: bet.ticket_number,
                sportsbook: bet.sportsbook || null,
                type: bet.type,
                status: bet.status,
                risk: bet.risk,
                to_win: bet.to_win,
                odds: bet.odds,
                legs: betLegs
              },
              created_at: bet.created_at
            })
          }
        }

        // Sort matches by confidence score (highest first)
        matches.sort((a, b) => b.confidence - a.confidence)
      }
    }

    // Return the matching results
    // Limit to top 5 matches to avoid overwhelming the user with choices
    const response = {
      success: true,
      matches: matches.slice(0, 5) // Return top 5 matches sorted by confidence
    }
    
    console.log('find-matching-bet: Returning response:', JSON.stringify(response))
    
    return new Response(
      JSON.stringify(response),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    // Log the error for debugging
    console.error('Error in find-matching-bet function:', error)
    
    // Determine appropriate HTTP status code based on error type
    let status = 400  // Default to bad request
    if (error.message === 'Unauthorized' || error.message === 'Missing authorization header') {
      status = 401  // Unauthorized if authentication fails
    }
    
    // Return error response
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: status
      }
    )
  }
})