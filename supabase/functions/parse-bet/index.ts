// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"

import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'
import { parseBetScreenshot } from '../_shared/vision.ts'

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body = await req.json()
    const { screenshot } = body

    if (!screenshot) {
      throw new Error('Missing required field: screenshot')
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

    // Parse bet data from screenshot using vision API
    console.log('Parsing bet screenshot...')
    const betData = await parseBetScreenshot(screenshot)
    console.log('Parsed bet data:', JSON.stringify(betData, null, 2))

    // Return parsed data for client approval
    return new Response(
      JSON.stringify({
        success: true,
        bet_data: betData
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in parse-bet function:', error)
    
    // Determine appropriate status code
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