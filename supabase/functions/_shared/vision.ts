import { BetData, BetSettlement } from './types.ts'

// Parse bet data from screenshot using OpenAI Vision API
export async function parseBetScreenshot(base64Image: string): Promise<BetData> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    throw new Error('OPENAI_API_KEY not configured')
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4-vision-preview',
      messages: [
        {
          role: 'system',
          content: `You are a bet slip parser. Extract bet information from sportsbook screenshots and return JSON.
          
          Return format:
          {
            "sportsbook": "name or null if unclear",
            "ticket_number": "extracted ticket/reference number",
            "type": "straight|parlay|teaser|round_robin|futures",
            "odds": "+150 or -110 format",
            "risk": 100.00,
            "to_win": 150.00,
            "status": "pending",
            "legs": [
              {
                "event": "Team A @ Team B or Future Event Name",
                "market": "ML|Spread|Total|Props|Future",
                "selection": "Team A -3.5 or Over 45.5",
                "odds": "-110"
              }
            ]
          }
          
          For futures bets, use "Future: [description]" as the event name.`
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Parse this bet slip and extract all information'
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${base64Image}`
              }
            }
          ]
        }
      ],
      max_tokens: 1000,
      temperature: 0
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`OpenAI API error: ${error}`)
  }

  const result = await response.json()
  const content = result.choices[0].message.content
  
  try {
    const parsed = JSON.parse(content)
    return parsed as BetData
  } catch (e) {
    throw new Error(`Failed to parse AI response: ${content}`)
  }
}

// Parse settlement screenshot to get bet result
export async function parseSettlementScreenshot(base64Image: string): Promise<BetSettlement> {
  const openaiKey = Deno.env.get('OPENAI_API_KEY')
  if (!openaiKey) {
    throw new Error('OPENAI_API_KEY not configured')
  }

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${openaiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4-vision-preview',
      messages: [
        {
          role: 'system',
          content: `You are a bet result parser. Extract the ticket number and result status from bet result screenshots.
          
          Return format:
          {
            "ticket_number": "extracted ticket number",
            "status": "won|lost|void|push"
          }
          
          Look for keywords like: WON, WIN, LOST, LOSS, VOID, PUSH, CASHED, GRADED`
        },
        {
          role: 'user',
          content: [
            {
              type: 'text',
              text: 'Extract the ticket number and result from this bet screenshot'
            },
            {
              type: 'image_url',
              image_url: {
                url: `data:image/jpeg;base64,${base64Image}`
              }
            }
          ]
        }
      ],
      max_tokens: 200,
      temperature: 0
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`OpenAI API error: ${error}`)
  }

  const result = await response.json()
  const content = result.choices[0].message.content
  
  try {
    const parsed = JSON.parse(content)
    return parsed as BetSettlement
  } catch (e) {
    throw new Error(`Failed to parse AI response: ${content}`)
  }
}