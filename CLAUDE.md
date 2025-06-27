# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hyphyness Tracker is a cross-platform bet tracking system that captures sportsbook screenshots, tracks participants' stakes, and manages payouts. The system consists of:
- macOS menu-bar app for screenshot capture and bet entry
- Supabase backend with PostgreSQL database and Edge Functions
- AI-powered screenshot parsing using Google Vision API and Claude

## Architecture

### Key Components
1. **macOS App** (Swift/SwiftUI): Menu bar app that handles screenshot capture, bet entry, and settlement
2. **Supabase Backend**: 
   - PostgreSQL database with RLS policies
   - Edge Functions for bet processing, settlement, and payments
   - Authentication and user management
3. **AI Integration**: Vision API + Claude for parsing bet screenshots and extracting structured data

### Database Schema
- `users`: User accounts and profiles
- `bets`: Main bet records with ticket info, odds (American format: +150, -110), and status
- `bet_legs`: Individual legs for parlay bets  
- `bet_participants`: Tracks who has stake in each bet and payment obligations
- `payments`: Records of payments between users

### Critical Business Logic
- **Odds Format**: Always use American odds format (+150, -110). Never store as fractions or with dollar signs
- **Participant Stakes**: Must sum to total risk amount
- **Settlement**: Matches settled bet screenshots to pending bets using ticket number and bet details
- **Payment Tracking**: Tracks who paid for the bet and who owes what after settlement

## Development Commands

### macOS App (BetTracker)
```bash
# Build the macOS app
cd macos/BetTracker
xcodebuild -project BetTracker.xcodeproj -scheme BetTracker build

# Run tests
xcodebuild -project BetTracker.xcodeproj -scheme BetTracker test
```

### Supabase Backend
```bash
# Start local Supabase (PostgreSQL on 54322, API on 54321, Studio on 54323)
supabase start

# Run database migrations
supabase db push

# Deploy Edge Functions
supabase functions deploy

# Link to production
supabase link --project-ref anxncoikpbipuplrkqrd
```

### Root Level Scripts
```bash
# Set up test users
npm run setup-users

# Create test bets
npm run test-bets

# Generate admin dashboard link
npm run admin-link
```

## macOS App Keyboard Shortcuts
- **⌥⇧4** - Take Bet Screenshot (uses macOS screenshot tool)
- **⌥⇧N** - Manual Bet Entry
- **⌥⇧L** - Load Bet Screenshot
- **⌘,** - Settings
- **⌘Q** - Quit

## Edge Function Environment Variables
Required in Supabase dashboard:
- `ANTHROPIC_API_KEY` - For Claude AI parsing
- `GOOGLE_CLOUD_API_KEY` - For Vision API text extraction

## Common Tasks

### Adding a New Bet
1. User takes screenshot or enters manually
2. App extracts text using Vision API
3. Claude parses bet details (type, odds, risk, to_win, legs)
4. User enters participants and their stakes
5. Edge function creates bet record with participants

### Settling a Bet
1. User takes screenshot of settled bet
2. System finds matching pending bet by ticket number
3. If no match, creates new settled bet record
4. Calculates payouts based on participants' stakes
5. Updates payment obligations

### Fixing Odds Format Issues
Check `supabase/functions/_shared/vision.ts` for Claude prompt that enforces American odds format. The `add-bet` function validates and normalizes odds before storage.

## Testing Approach
- macOS app: Unit tests for participant parsing and bet calculations
- Edge Functions: Deploy to Supabase and test via API calls
- Use test data scripts (`setup-users.js`, `test-bets.js`) for consistent test scenarios