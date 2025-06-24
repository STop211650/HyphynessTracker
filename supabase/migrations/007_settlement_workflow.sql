-- Add settlement workflow enhancements

-- Add settlement tracking fields to bets table
ALTER TABLE bets 
ADD COLUMN settlement_proposed_by uuid REFERENCES users(id),
ADD COLUMN settlement_proposed_at timestamptz,
ADD COLUMN is_disputed boolean DEFAULT false,
ADD COLUMN dispute_reason text;

-- Create settlement confirmations table
CREATE TABLE settlement_confirmations (
  bet_id uuid REFERENCES bets(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id),
  confirmed boolean DEFAULT false,
  confirmed_at timestamptz,
  disputed boolean DEFAULT false,
  dispute_reason text,
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (bet_id, user_id)
);

-- Create index for settlement queries
CREATE INDEX idx_settlement_confirmations_bet_id ON settlement_confirmations(bet_id);
CREATE INDEX idx_settlement_confirmations_user_id ON settlement_confirmations(user_id);

-- Function to check if all participants have confirmed settlement
CREATE OR REPLACE FUNCTION check_settlement_complete(p_bet_id uuid)
RETURNS boolean AS $$
DECLARE
  participant_count integer;
  confirmation_count integer;
BEGIN
  -- Get total participants
  SELECT COUNT(*) INTO participant_count
  FROM bet_participants
  WHERE bet_id = p_bet_id;
  
  -- Get confirmed participants
  SELECT COUNT(*) INTO confirmation_count
  FROM settlement_confirmations
  WHERE bet_id = p_bet_id AND confirmed = true;
  
  RETURN participant_count = confirmation_count AND participant_count > 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to initiate settlement
CREATE OR REPLACE FUNCTION initiate_settlement(
  p_bet_id uuid,
  p_user_id uuid,
  p_status text,
  p_result_screenshot text DEFAULT NULL
) RETURNS json AS $$
DECLARE
  v_bet record;
  v_participants uuid[];
BEGIN
  -- Validate bet exists and user is a participant
  SELECT b.*, bp.user_id IS NOT NULL as is_participant
  INTO v_bet
  FROM bets b
  LEFT JOIN bet_participants bp ON bp.bet_id = b.id AND bp.user_id = p_user_id
  WHERE b.id = p_bet_id;
  
  IF NOT FOUND OR NOT v_bet.is_participant THEN
    RAISE EXCEPTION 'Bet not found or user is not a participant';
  END IF;
  
  IF v_bet.status != 'pending' THEN
    RAISE EXCEPTION 'Bet is not in pending status';
  END IF;
  
  -- Update bet with proposed settlement
  UPDATE bets SET
    settlement_proposed_by = p_user_id,
    settlement_proposed_at = now(),
    status = p_status,
    result_screenshot_url = COALESCE(p_result_screenshot, result_screenshot_url)
  WHERE id = p_bet_id;
  
  -- Get all participants
  SELECT array_agg(user_id) INTO v_participants
  FROM bet_participants
  WHERE bet_id = p_bet_id;
  
  -- Create confirmation records for all participants
  INSERT INTO settlement_confirmations (bet_id, user_id, confirmed, confirmed_at)
  SELECT p_bet_id, unnest(v_participants), 
    CASE WHEN unnest(v_participants) = p_user_id THEN true ELSE false END,
    CASE WHEN unnest(v_participants) = p_user_id THEN now() ELSE NULL END
  ON CONFLICT (bet_id, user_id) DO UPDATE
  SET confirmed = EXCLUDED.confirmed,
      confirmed_at = EXCLUDED.confirmed_at;
  
  RETURN json_build_object(
    'success', true,
    'bet_id', p_bet_id,
    'status', p_status,
    'confirmations_needed', array_length(v_participants, 1) - 1
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to confirm or dispute settlement
CREATE OR REPLACE FUNCTION respond_to_settlement(
  p_bet_id uuid,
  p_user_id uuid,
  p_confirmed boolean,
  p_dispute_reason text DEFAULT NULL
) RETURNS json AS $$
DECLARE
  v_bet record;
  v_all_confirmed boolean;
BEGIN
  -- Validate bet and user
  SELECT b.*, sc.user_id IS NOT NULL as has_confirmation
  INTO v_bet
  FROM bets b
  LEFT JOIN settlement_confirmations sc ON sc.bet_id = b.id AND sc.user_id = p_user_id
  WHERE b.id = p_bet_id;
  
  IF NOT FOUND OR NOT v_bet.has_confirmation THEN
    RAISE EXCEPTION 'Invalid bet or user not a participant';
  END IF;
  
  IF v_bet.status NOT IN ('won', 'lost', 'void', 'push') THEN
    RAISE EXCEPTION 'No settlement proposed for this bet';
  END IF;
  
  -- Update confirmation
  UPDATE settlement_confirmations
  SET confirmed = p_confirmed,
      confirmed_at = now(),
      disputed = NOT p_confirmed,
      dispute_reason = p_dispute_reason
  WHERE bet_id = p_bet_id AND user_id = p_user_id;
  
  -- If disputed, update bet
  IF NOT p_confirmed THEN
    UPDATE bets
    SET is_disputed = true,
        dispute_reason = p_dispute_reason
    WHERE id = p_bet_id;
    
    RETURN json_build_object(
      'success', true,
      'bet_id', p_bet_id,
      'disputed', true,
      'message', 'Settlement disputed'
    );
  END IF;
  
  -- Check if all confirmed
  v_all_confirmed := check_settlement_complete(p_bet_id);
  
  IF v_all_confirmed THEN
    -- All confirmed, finalize settlement
    UPDATE bets
    SET settled_at = now()
    WHERE id = p_bet_id;
    
    -- Update payouts based on result
    PERFORM update_bet_payouts(p_bet_id);
  END IF;
  
  RETURN json_build_object(
    'success', true,
    'bet_id', p_bet_id,
    'all_confirmed', v_all_confirmed,
    'message', CASE WHEN v_all_confirmed THEN 'Settlement complete' ELSE 'Confirmation recorded' END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add RLS policies
ALTER TABLE settlement_confirmations ENABLE ROW LEVEL SECURITY;

-- Users can only see confirmations for bets they're part of
CREATE POLICY "Users can view their bet confirmations" ON settlement_confirmations
FOR SELECT USING (
  user_id = auth.uid() OR
  bet_id IN (SELECT bet_id FROM bet_participants WHERE user_id = auth.uid())
);

-- Users can only update their own confirmations
CREATE POLICY "Users can update their own confirmations" ON settlement_confirmations
FOR UPDATE USING (user_id = auth.uid());