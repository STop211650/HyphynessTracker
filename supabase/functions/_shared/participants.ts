import { Participant } from './types.ts'

// Parse participant text like "Sam: 50, Alex: 30, Jordan: 20"
export function parseParticipants(text: string): Participant[] {
  const participants: Participant[] = []
  
  // Split by comma and process each participant
  const parts = text.split(',')
  
  for (const part of parts) {
    const trimmed = part.trim()
    if (!trimmed) continue
    
    // Match patterns like "Name: amount" or "Name $amount" or "Name amount"
    const match = trimmed.match(/^([^:$]+)[:$]?\s*(\d+(?:\.\d{2})?)$/)
    
    if (match) {
      const name = match[1].trim()
      const stake = parseFloat(match[2])
      
      if (name && stake > 0) {
        participants.push({ name, stake })
      }
    }
  }
  
  return participants
}

// Validate that stakes sum to the bet risk amount
export function validateStakes(participants: Participant[], risk: number): boolean {
  const totalStake = participants.reduce((sum, p) => sum + p.stake, 0)
  // Allow small rounding differences (up to 1 cent)
  return Math.abs(totalStake - risk) < 0.01
}