-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE bets ENABLE ROW LEVEL SECURITY;
ALTER TABLE bet_legs ENABLE ROW LEVEL SECURITY;
ALTER TABLE bet_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Users policies
-- Users can view their own profile
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE
  USING (auth.uid() = id);

-- Authenticated users can view all users (for participant selection)
CREATE POLICY "Authenticated users can view all users" ON users
  FOR SELECT
  TO authenticated
  USING (true);

-- Bets policies
-- Users can view bets they created or are participants in
CREATE POLICY "Users can view their bets" ON bets
  FOR SELECT
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM bet_participants bp
      WHERE bp.bet_id = bets.id AND bp.user_id = auth.uid()
    )
  );

-- Users can create bets
CREATE POLICY "Users can create bets" ON bets
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = created_by);

-- Users can update their own created bets
CREATE POLICY "Users can update own bets" ON bets
  FOR UPDATE
  USING (auth.uid() = created_by);

-- Bet legs policies
-- Users can view legs for bets they can see
CREATE POLICY "Users can view bet legs" ON bet_legs
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = bet_legs.bet_id AND (
        b.created_by = auth.uid() OR
        EXISTS (
          SELECT 1 FROM bet_participants bp
          WHERE bp.bet_id = b.id AND bp.user_id = auth.uid()
        )
      )
    )
  );

-- Users can create legs for their bets
CREATE POLICY "Users can create bet legs" ON bet_legs
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = bet_legs.bet_id AND b.created_by = auth.uid()
    )
  );

-- Bet participants policies
-- Users can view participants for bets they're involved in
CREATE POLICY "Users can view bet participants" ON bet_participants
  FOR SELECT
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = bet_participants.bet_id AND b.created_by = auth.uid()
    )
  );

-- Bet creators can add participants
CREATE POLICY "Bet creators can add participants" ON bet_participants
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = bet_participants.bet_id AND b.created_by = auth.uid()
    )
  );

-- Bet creators can update participants
CREATE POLICY "Bet creators can update participants" ON bet_participants
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = bet_participants.bet_id AND b.created_by = auth.uid()
    )
  );

-- Payments policies
-- Users can view payments they're involved in or for bets they created
CREATE POLICY "Users can view their payments" ON payments
  FOR SELECT
  USING (
    from_user_id = auth.uid() OR 
    to_user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = payments.bet_id AND b.created_by = auth.uid()
    )
  );

-- Users can create payments if they're involved in the bet
-- This allows recording payments on behalf of others if you're the bet creator
CREATE POLICY "Users can create payments" ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    -- User is the sender
    from_user_id = auth.uid() OR
    -- User created the bet (can record payments for others)
    EXISTS (
      SELECT 1 FROM bets b
      WHERE b.id = payments.bet_id AND b.created_by = auth.uid()
    ) OR
    -- User is a participant in the bet
    EXISTS (
      SELECT 1 FROM bet_participants bp
      WHERE bp.bet_id = payments.bet_id AND bp.user_id = auth.uid()
    )
  );

-- Create service role bypass policies for Edge Functions
-- These will be used by Edge Functions running with service role key
CREATE POLICY "Service role has full access to users" ON users
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to bets" ON bets
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to bet_legs" ON bet_legs
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to bet_participants" ON bet_participants
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Service role has full access to payments" ON payments
  TO service_role
  USING (true)
  WITH CHECK (true);