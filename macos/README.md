# BetTracker macOS App

A menu bar application for capturing and tracking sports bets with friends.

## Features

- 📸 **Screenshot Capture**: Quick screenshot of bet slips with Cmd+Shift+S
- ✏️ **Manual Entry**: Enter bet details manually without screenshot (Cmd+Shift+N)
- 💬 **Natural Language Input**: Enter participants like "Sam, Alex split equally" or "Sam 50, Alex 30"
- ✅ **Approval Workflow**: Review and edit parsed bet details before submission
- 💰 **Settlement Interface**: Mark bets as won/lost/push/void for accurate bookkeeping
- 🎯 **Smart Settlement Matching**: Automatically match settled bet screenshots to pending bets
- 🔐 **Secure Authentication**: Login with Supabase credentials, tokens stored in Keychain
- ⚙️ **Customizable Settings**: Choose screenshot location and approval preferences
- 🔒 **API Security**: All third-party API calls routed through secure Edge Functions

## Building the App

1. Open `BetTracker/BetTracker.xcodeproj` in Xcode
2. Select your development team in project settings
3. Build and run (Cmd+R)

## Project Structure

```
BetTracker/
├── BetTrackerApp.swift      # Main app entry point
├── Views/                   # UI Components
│   ├── AuthenticationView.swift
│   ├── BetApprovalView.swift
│   ├── BetDetailsInputView.swift
│   ├── ManualBetEntryView.swift
│   ├── ParsingView.swift
│   ├── SettlementView.swift
│   └── SettingsView.swift
├── Services/                # Business Logic
│   ├── AuthenticationManager.swift
│   └── SupabaseClient.swift
├── Utils/                   # Helpers
│   └── ParticipantParser.swift
└── Models/                  # Data Models (currently empty)
```

## Usage

### Capturing Bets from Screenshots
1. Launch the app - it appears in your menu bar as 🎲
2. Sign in with your Supabase account
3. Click "Take Bet Screenshot" or use Cmd+Shift+S
4. Select the area of your bet slip
5. Wait for the screenshot to be analyzed (parsing view shown)
6. Enter participants in natural language
7. Review and approve the parsed details
8. Bet is submitted to Supabase

### Manual Bet Entry
1. Click "Manual Bet Entry" or use Cmd+Shift+N
2. Fill in bet details (ticket number, odds, amounts)
3. Add parlay legs if needed
4. Enter participants in natural language
5. Review and approve the details
6. Bet is submitted to Supabase

### Settling Bets

#### Option 1: Manual Settlement
1. Active bets appear in the menu with a "Settle" button
2. Click "Settle" on any pending bet
3. Choose the result: Won, Lost, Push, or Void
4. Confirm to update balances automatically

#### Option 2: Settlement with Screenshot
1. Take a screenshot of a settled bet (showing the result)
2. The app automatically detects it's settled
3. Matching pending bets are shown with confidence scores
4. Select the correct match to update it
5. Balances are updated based on the settlement result

## Configuration

Settings available via Cmd+, :
- **Screenshot Location**: Where to save bet screenshots
- **Approval Settings**: Always require approval or auto-approve high confidence bets

## Development

- Built with SwiftUI for macOS 11.0+
- Uses Supabase for backend
- Secure credential storage via Keychain Services
- No external Swift packages required

See `/docs/macos/PRD-Implementation.md` for detailed implementation notes.