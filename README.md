# Hyphyness Tracker

A cross-platform bet tracking system that captures sportsbook screenshots, tracks participants' stakes, and manages payouts.

## Features

- **Screenshot Capture**: macOS menu-bar app and iOS Shortcuts
- **AI Parsing**: Automatic extraction of bet details from screenshots
- **Multi-User Support**: Track stakes from multiple participants with uneven splits
- **Settlement Tracking**: Upload result screenshots to settle pending bets
- **Payment Management**: Track who owes what and record payments
- **Web Portal**: Dashboard for viewing bets, balances, and exporting data

## Tech Stack

- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Frontend**: Next.js web application
- **Native**: macOS menu-bar app, iOS Shortcuts
- **AI**: Vision API for screenshot parsing

## Project Structure

```
hyphyness-tracker/
├── supabase/           # Database schema and Edge Functions
├── web/                # Next.js web portal
├── macos/              # macOS menu-bar application
├── ios/                # iOS Shortcuts configuration
└── docs/               # Additional documentation
```

## Getting Started

1. Clone the repository
2. Set up Supabase project
3. Configure environment variables
4. Install dependencies
5. Run development servers

See individual README files in each directory for specific setup instructions.