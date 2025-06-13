-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Users table
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email text UNIQUE NOT NULL,
  name text UNIQUE NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Bets table
CREATE TABLE bets (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number text UNIQUE NOT NULL,
  sportsbook text, -- Optional, may not be identifiable from screenshot
  type text NOT NULL CHECK (type IN ('straight', 'parlay', 'teaser', 'round_robin', 'futures')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'won', 'lost', 'void', 'push')),
  risk numeric(10,2) NOT NULL,
  to_win numeric(10,2) NOT NULL,
  payout_total numeric(10,2) DEFAULT 0,
  odds text NOT NULL,
  placed_at timestamptz DEFAULT now(),
  settled_at timestamptz,
  created_by uuid REFERENCES users(id) NOT NULL,
  screenshot_url text,
  result_screenshot_url text
);

-- Bet legs table for parlays
CREATE TABLE bet_legs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  bet_id uuid REFERENCES bets(id) ON DELETE CASCADE NOT NULL,
  event text NOT NULL,
  market text NOT NULL,
  selection text NOT NULL,
  odds text NOT NULL,
  result text CHECK (result IN ('won', 'lost', 'void', 'push'))
);

-- Bet participants table
CREATE TABLE bet_participants (
  bet_id uuid REFERENCES bets(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  stake numeric(10,2) NOT NULL,
  payout_due numeric(10,2) DEFAULT 0,
  is_paid boolean DEFAULT false,
  PRIMARY KEY (bet_id, user_id)
);

-- Payments table
CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  bet_id uuid REFERENCES bets(id),
  from_user_id uuid REFERENCES users(id) NOT NULL,
  to_user_id uuid REFERENCES users(id) NOT NULL,
  amount numeric(10,2) NOT NULL,
  payment_method text,
  note text,
  paid_at timestamptz DEFAULT now()
);

-- Create indexes for better query performance
CREATE INDEX idx_bets_status ON bets(status);
CREATE INDEX idx_bets_ticket_number ON bets(ticket_number);
CREATE INDEX idx_bets_created_by ON bets(created_by);
CREATE INDEX idx_bet_participants_user_id ON bet_participants(user_id);
CREATE INDEX idx_payments_from_user ON payments(from_user_id);
CREATE INDEX idx_payments_to_user ON payments(to_user_id);

-- Create views for easier querying
CREATE VIEW v_user_ledger AS
SELECT 
  bp.user_id,
  u.name as user_name,
  b.id as bet_id,
  b.ticket_number,
  b.placed_at,
  b.status,
  bp.stake,
  bp.payout_due,
  bp.is_paid,
  CASE 
    WHEN b.status = 'won' THEN bp.payout_due - bp.stake
    WHEN b.status IN ('lost', 'void') THEN -bp.stake
    ELSE 0
  END as profit_loss
FROM bet_participants bp
JOIN users u ON u.id = bp.user_id
JOIN bets b ON b.id = bp.bet_id;

-- View for outstanding balances
CREATE VIEW v_user_balance AS
SELECT 
  u.id as user_id,
  u.name,
  u.email,
  COALESCE(SUM(
    CASE 
      WHEN b.status = 'pending' THEN bp.stake
      ELSE 0
    END
  ), 0) as total_pending,
  COALESCE(SUM(
    CASE 
      WHEN b.status = 'won' AND NOT bp.is_paid THEN bp.payout_due - bp.stake
      WHEN b.status = 'lost' AND NOT bp.is_paid THEN -bp.stake
      ELSE 0
    END
  ), 0) as outstanding_balance,
  COALESCE(SUM(bp.stake), 0) as total_staked,
  COALESCE(SUM(
    CASE 
      WHEN b.status = 'won' THEN bp.payout_due
      ELSE 0
    END
  ), 0) as total_returned
FROM users u
LEFT JOIN bet_participants bp ON bp.user_id = u.id
LEFT JOIN bets b ON b.id = bp.bet_id
GROUP BY u.id, u.name, u.email;