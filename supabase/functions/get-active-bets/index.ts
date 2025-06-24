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

    // Get active bets where user is a participant
    const { data: bets, error: betsError } = await supabase
      .from('bets')
      .select(`
        *,
        bet_participants!inner (
          user_id,
          stake,
          users (
            id,
            name,
            email
          )
        )
      `)
      .eq('status', 'pending')
      .eq('bet_participants.user_id', user.id)
      .order('placed_at', { ascending: false })

    if (betsError) {
      throw new Error(`Failed to fetch bets: ${betsError.message}`)
    }

    // Transform the data to include all participants for each bet
    const transformedBets = await Promise.all(
      (bets || []).map(async (bet) => {
        // Get all participants for this bet
        const { data: allParticipants, error: participantsError } = await supabase
          .from('bet_participants')
          .select(`
            user_id,
            stake,
            users (
              id,
              name,
              email
            )
          `)
          .eq('bet_id', bet.id)

        if (participantsError) {
          console.error(`Error fetching participants for bet ${bet.id}:`, participantsError)
        }

        return {
          id: bet.id,
          ticket_number: bet.ticket_number,
          risk: bet.risk,
          to_win: bet.to_win,
          odds: bet.odds,
          status: bet.status,
          placed_at: bet.placed_at,
          participants: (allParticipants || []).map(p => ({
            user_id: p.user_id,
            name: p.users?.name || 'Unknown',
            stake: p.stake
          }))
        }
      })
    )

    // Return active bets
    return new Response(
      JSON.stringify({
        success: true,
        bets: transformedBets
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in get-active-bets function:', error)
    
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