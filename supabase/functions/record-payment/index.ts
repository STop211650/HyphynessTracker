import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'
import { supabase } from '../_shared/supabase.ts'
import { RecordPaymentRequest } from '../_shared/types.ts'

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Parse request body
    const body: RecordPaymentRequest = await req.json()
    const { bet_id, from_user_name, to_user_name, amount, payment_method, note } = body

    if (!bet_id || !from_user_name || !to_user_name || !amount) {
      throw new Error('Missing required fields')
    }

    if (amount <= 0) {
      throw new Error('Payment amount must be positive')
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

    // Get the bet to verify permissions
    const { data: bet, error: betError } = await supabase
      .from('bets')
      .select('*, bet_participants(user_id)')
      .eq('id', bet_id)
      .single()

    if (betError || !bet) {
      throw new Error('Bet not found')
    }

    // Check if user has permission to record this payment
    const isCreator = bet.created_by === user.id
    const isParticipant = bet.bet_participants.some((p: any) => p.user_id === user.id)

    if (!isCreator && !isParticipant) {
      throw new Error('You do not have permission to record payments for this bet')
    }

    // Get user IDs for from and to users
    const { data: fromUser, error: fromError } = await supabase
      .from('users')
      .select('id')
      .eq('name', from_user_name)
      .single()

    if (fromError || !fromUser) {
      throw new Error(`User not found: ${from_user_name}`)
    }

    const { data: toUser, error: toError } = await supabase
      .from('users')
      .select('id')
      .eq('name', to_user_name)
      .single()

    if (toError || !toUser) {
      throw new Error(`User not found: ${to_user_name}`)
    }

    // Create payment record
    const { data: payment, error: paymentError } = await supabase
      .from('payments')
      .insert([{
        bet_id,
        from_user_id: fromUser.id,
        to_user_id: toUser.id,
        amount,
        payment_method,
        note
      }])
      .select()
      .single()

    if (paymentError) {
      throw new Error(`Failed to record payment: ${paymentError.message}`)
    }

    // Get current balances for both users to determine payment impact
    const { data: fromBalance } = await supabase
      .rpc('get_user_net_position', { user_uuid: fromUser.id })
    
    const { data: toBalance } = await supabase
      .rpc('get_user_net_position', { user_uuid: toUser.id })

    // Update is_paid status for specific bet participants based on the payment
    // This payment reduces the payer's outstanding debt and/or pays the receiver
    
    // For the payer: if they had negative balance and this payment covers it
    if (fromBalance && fromBalance[0]?.outstanding_balance < 0) {
      const newBalance = fromBalance[0].outstanding_balance + amount
      if (newBalance >= 0) {
        // Payment covers their debt, mark relevant bet participants as paid
        await supabase
          .from('bet_participants')
          .update({ is_paid: true })
          .eq('bet_id', bet_id)
          .eq('user_id', fromUser.id)
          .eq('is_paid', false)
      }
    }

    // For the receiver: if they had positive balance and this payment settles it
    if (toBalance && toBalance[0]?.outstanding_balance > 0) {
      const newBalance = toBalance[0].outstanding_balance - amount
      if (newBalance <= 0) {
        // They've been paid what they were owed, mark as paid
        await supabase
          .from('bet_participants')
          .update({ is_paid: true })
          .eq('bet_id', bet_id)
          .eq('user_id', toUser.id)
          .eq('is_paid', false)
      }
    }

    // Calculate net effect of this payment
    const netEffect = {
      from_user: {
        name: from_user_name,
        balance_change: -amount, // They paid out
        new_outstanding: (fromBalance?.[0]?.outstanding_balance || 0) + amount
      },
      to_user: {
        name: to_user_name,
        balance_change: amount, // They received
        new_outstanding: (toBalance?.[0]?.outstanding_balance || 0) - amount
      }
    }

    // Return success
    return new Response(
      JSON.stringify({
        success: true,
        payment: {
          id: payment.id,
          bet_id: payment.bet_id,
          from: from_user_name,
          to: to_user_name,
          amount: payment.amount,
          payment_method: payment.payment_method,
          paid_at: payment.paid_at,
          net_effect: netEffect
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('Error in record-payment function:', error)
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