import { BetData, BetSettlement } from './types.ts'

// Parse bet data from screenshot using Google Cloud Vision + Claude
export async function parseBetScreenshot(base64Image: string): Promise<BetData> {
  // First, extract text using Google Cloud Vision
  const extractedText = await extractTextFromImage(base64Image)
  
  // Then, parse the text using Claude
  const claudeKey = Deno.env.get('ANTHROPIC_API_KEY')
  if (!claudeKey) {
    throw new Error('ANTHROPIC_API_KEY not configured')
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': claudeKey,
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-3-haiku-20240307',
      max_tokens: 1000,
      messages: [
        {
          role: 'user',
          content: `Parse this bet slip text and extract bet information. Return ONLY valid JSON with no additional text, explanation, or markdown formatting.

Text from bet slip:
${extractedText}

IMPORTANT RULES FOR DETERMINING RISK vs TO WIN:
1. FIRST PRIORITY: Look for explicit labels like "RISK:", "TO WIN:", "WAGER:", "BET:", "STAKE:", "PAYOUT:", "WIN:", etc.
   - If you see "RISK: $210.00" and "TO WIN: $200.00", use those exact amounts
   - Do NOT reverse or swap these amounts based on odds calculations
   
2. ONLY if no explicit labels are found, use the odds to infer:
   - For negative odds (e.g., -180): The larger amount is the risk, smaller is the potential win
   - For positive odds (e.g., +150): The smaller amount is the risk, larger is the potential win

3. For settled/won bets:
   - The amounts shown are typically: amount risked and profit/winnings (not including stake)
   - Look for labels like "WON:", "PAYOUT:", "PROFIT:" to identify winnings

Return format:
{
  "sportsbook": "name or null if unclear",
  "ticket_number": "extracted ticket/reference number",
  "type": "straight|parlay|teaser|round_robin|futures",
  "odds": "+150 or -110 format (MUST be American odds format: + for positive, - for negative, followed by a number)",
  "risk": 100.00,
  "to_win": 150.00,
  "status": "pending|won|lost|push|void",
  "legs": [
    {
      "event": "Team A @ Team B or Team A vs Team B",
      "market": "ML|Spread|Total|Props|Future",
      "selection": "Team A -3.5 or Over 45.5 or Under 45.5",
      "odds": "-110"
    }
  ]
}

CRITICAL ODDS FORMAT RULES:
- ALWAYS return odds in American format: "+150", "-110", "+100", "-200"
- NEVER return odds as fractions like "-$100/$290" or "100/290"
- NEVER include dollar signs in odds
- For even money bets, use "+100" or "-100"
- If you see odds displayed as "risk $X to win $Y", calculate the American odds:
  - If to_win > risk: odds = "+" + round((to_win/risk) * 100)
  - If to_win < risk: odds = "-" + round((risk/to_win) * 100)
  - If to_win = risk: odds = "+100"

IMPORTANT for parsing totals:
- "TOTAL o9-105" means "Over 9" at odds "-105"
- "TOTAL u9-105" means "Under 9" at odds "-105"
- The number after o/u is the total line, followed by the odds
- Always separate the selection (Over/Under + number) from the odds

For futures bets, use "Future: [description]" as the event name.`
        }
      ]
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Claude API error: ${error}`)
  }

  const result = await response.json()
  const content = result.content[0].text
  
  try {
    // Try to parse the content directly first
    const parsed = JSON.parse(content)
    
    // Calculate odds if not provided (common for parlays)
    if (!parsed.odds && parsed.risk && parsed.to_win) {
      const ratio = parsed.to_win / parsed.risk
      if (ratio >= 1) {
        // Positive odds
        parsed.odds = `+${Math.round(ratio * 100)}`
      } else {
        // Negative odds
        parsed.odds = `-${Math.round(100 / ratio)}`
      }
    }
    
    return parsed as BetData
  } catch (e) {
    // If direct parsing fails, try to extract JSON from the text
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0]);
        
        // Calculate odds if not provided
        if (!parsed.odds && parsed.risk && parsed.to_win) {
          const ratio = parsed.to_win / parsed.risk
          if (ratio >= 1) {
            parsed.odds = `+${Math.round(ratio * 100)}`
          } else {
            parsed.odds = `-${Math.round(100 / ratio)}`
          }
        }
        
        return parsed as BetData;
      } catch (innerError) {
        throw new Error(`Failed to parse AI response: ${content}`)
      }
    } else {
      throw new Error(`Failed to parse AI response: ${content}`)
    }
  }
}

// Extract text from image using Google Cloud Vision
async function extractTextFromImage(base64Image: string): Promise<string> {
  const googleKey = Deno.env.get('GOOGLE_CLOUD_API_KEY')
  if (!googleKey) {
    throw new Error('GOOGLE_CLOUD_API_KEY not configured')
  }

  const response = await fetch(`https://vision.googleapis.com/v1/images:annotate?key=${googleKey}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      requests: [
        {
          image: {
            content: base64Image
          },
          features: [
            {
              type: 'DOCUMENT_TEXT_DETECTION',
              maxResults: 1
            }
          ]
        }
      ]
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Google Vision API error: ${error}`)
  }

  const result = await response.json()
  
  if (result.responses?.[0]?.fullTextAnnotation?.text) {
    return result.responses[0].fullTextAnnotation.text
  } else if (result.responses?.[0]?.textAnnotations?.length > 0) {
    return result.responses[0].textAnnotations[0].description
  } else {
    throw new Error('No text found in image')
  }
}

// Parse settlement screenshot to get bet result
export async function parseSettlementScreenshot(base64Image: string): Promise<BetSettlement> {
  // First, extract text using Google Cloud Vision
  const extractedText = await extractTextFromImage(base64Image)
  
  // Then, parse the text using Claude
  const claudeKey = Deno.env.get('ANTHROPIC_API_KEY')
  if (!claudeKey) {
    throw new Error('ANTHROPIC_API_KEY not configured')
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': claudeKey,
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-3-haiku-20240307',
      max_tokens: 200,
      messages: [
        {
          role: 'user',
          content: `Extract the ticket number and result status from this bet result text. Return JSON only.

Text from bet result:
${extractedText}

Return format:
{
  "ticket_number": "extracted ticket number",
  "status": "won|lost|void|push"
}

Look for keywords like: WON, WIN, LOST, LOSS, VOID, PUSH, CASHED, GRADED`
        }
      ]
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Claude API error: ${error}`)
  }

  const result = await response.json()
  const content = result.content[0].text
  
  try {
    const parsed = JSON.parse(content)
    return parsed as BetSettlement
  } catch (e) {
    throw new Error(`Failed to parse AI response: ${content}`)
  }
}