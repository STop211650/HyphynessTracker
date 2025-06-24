import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
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

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: MatchRequest = await req.json()
    const { bet_data, ticket_number } = body

    if (!bet_data) {
      throw new Error('Missing required field: bet_data')
    }

    // Get authenticated user
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

    const matches: BetMatch[] = []

    // Strategy 1: Exact ticket number match (highest confidence)
    if (ticket_number || bet_data.ticket_number) {
      const ticketToMatch = ticket_number || bet_data.ticket_number
      
      const { data: ticketMatches, error: ticketError } = await supabase
        .from('bets')
        .select('*')
        .eq('placer_id', authUser.id)
        .eq('status', 'pending')
        .eq('ticket_number', ticketToMatch)

      if (!ticketError && ticketMatches && ticketMatches.length > 0) {
        ticketMatches.forEach(bet => {
          matches.push({
            id: bet.id,
            confidence: 100,
            bet_data: bet.bet_data,
            created_at: bet.created_at
          })
        })
      }
    }

    // Strategy 2: Fuzzy matching on multiple attributes
    if (matches.length === 0) {
      // Get all pending bets for the user from the last 30 days
      const thirtyDaysAgo = new Date()
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)

      const { data: pendingBets, error: pendingError } = await supabase
        .from('bets')
        .select('*')
        .eq('placer_id', authUser.id)
        .eq('status', 'pending')
        .gte('created_at', thirtyDaysAgo.toISOString())

      if (!pendingError && pendingBets) {
        // Score each bet based on matching attributes
        pendingBets.forEach(bet => {
          let score = 0
          const existingData = bet.bet_data as BetData

          // Check sportsbook match (20 points)
          if (bet_data.sportsbook && existingData.sportsbook && 
              bet_data.sportsbook.toLowerCase() === existingData.sportsbook.toLowerCase()) {
            score += 20
          }

          // Check bet type match (20 points)
          if (bet_data.type === existingData.type) {
            score += 20
          }

          // Check odds match (20 points)
          if (bet_data.odds === existingData.odds) {
            score += 20
          }

          // Check risk amount match with tolerance (25 points)
          const riskDiff = Math.abs(bet_data.risk - existingData.risk)
          if (riskDiff < 0.01) {
            score += 25
          } else if (riskDiff < 1.00) {
            score += 15
          }

          // Check to_win amount match with tolerance (15 points)
          const winDiff = Math.abs(bet_data.to_win - existingData.to_win)
          if (winDiff < 0.01) {
            score += 15
          } else if (winDiff < 1.00) {
            score += 10
          }

          // For parlays, check leg count
          if (bet_data.type === 'parlay' && existingData.type === 'parlay') {
            if (bet_data.legs?.length === existingData.legs?.length) {
              score += 10
            }
          }

          // Only include bets with reasonable confidence
          if (score >= 60) {
            matches.push({
              id: bet.id,
              confidence: score,
              bet_data: existingData,
              created_at: bet.created_at
            })
          }
        })

        // Sort by confidence
        matches.sort((a, b) => b.confidence - a.confidence)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        matches: matches.slice(0, 5) // Return top 5 matches
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in find-matching-bet function:', error)
    
    let status = 400
    if (error.message === 'Unauthorized' || error.message === 'Missing authorization header') {
      status = 401
    }
    
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