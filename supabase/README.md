# Supabase Backend Setup

This directory contains the database schema, Edge Functions, and configuration for the Hyphyness Tracker backend.

## Initial Setup

1. **Install Supabase CLI**
   ```bash
   brew install supabase/tap/supabase
   ```

2. **Link to your Supabase project**
   ```bash
   supabase link --project-ref anxncoikpbipuplrkqrd
   ```

3. **Run migrations**
   ```bash
   supabase db push
   ```

## Database Schema

The database consists of the following tables:

- **users**: User accounts and profiles
- **bets**: Main bet records with ticket info, odds, and status
- **bet_legs**: Individual legs for parlay bets
- **bet_participants**: Tracks who has stake in each bet
- **payments**: Records of payments between users

## Edge Functions

Located in the `functions/` directory:

- **add-bet**: Processes screenshot uploads and creates bet records
- **settle-bet**: Matches result screenshots to pending bets and calculates payouts
- **record-payment**: Records payment transactions between users
- **export-csv**: Generates CSV exports of bet history

## Row Level Security (RLS)

The database implements RLS policies to ensure:
- Users can only see bets they created or participate in
- Bet creators can manage participants and record payments
- All users can view other users for participant selection

## Development

To run Supabase locally:

```bash
supabase start
```

This will start:
- PostgreSQL database on port 54322
- API server on port 54321
- Studio UI on port 54323

## Testing

Use the provided seed data:

```bash
supabase db seed
```

## Deployment

Deploy database changes:

```bash
supabase db push
```

Deploy Edge Functions:

```bash
supabase functions deploy
```