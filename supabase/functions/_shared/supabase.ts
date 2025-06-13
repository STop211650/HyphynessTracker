import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

export const supabase = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
)

// Helper to get or create a user in our custom users table
// This is separate from Supabase Auth - it's for tracking bet participants
// who may not have accounts yet (identified by name only)
export async function getOrCreateParticipant(name: string) {
  // First try to find existing participant
  const { data: existingUser, error: findError } = await supabase
    .from('users')
    .select('*')
    .eq('name', name)
    .single()

  if (existingUser && !findError) {
    return { data: existingUser, error: null }
  }

  // Create new participant if not found
  // For now, we'll use a placeholder email until they create an account
  const { data: newUser, error: createError } = await supabase
    .from('users')
    .insert([{ 
      email: `${name.toLowerCase().replace(/\s+/g, '.')}@pending.hyphyness`,
      name 
    }])
    .select()
    .single()

  return { data: newUser, error: createError }
}

// Link a participant to an authenticated user when they sign up
export async function linkParticipantToAuth(participantName: string, authUserId: string, realEmail: string) {
  const { data, error } = await supabase
    .from('users')
    .update({ 
      id: authUserId,
      email: realEmail 
    })
    .eq('name', participantName)
    .select()
    .single()

  return { data, error }
}