-- Add bet placer tracking for debt management

-- Add who_paid_for field to bet_participants
ALTER TABLE bet_participants 
ADD COLUMN who_paid_for uuid REFERENCES users(id);

-- Add comment to clarify the fields
COMMENT ON COLUMN bet_participants.user_id IS 'Who the bet is for (participant)';
COMMENT ON COLUMN bet_participants.who_paid_for IS 'Who actually paid for this participants stake (bet placer)';

-- Create index for who_paid_for queries
CREATE INDEX idx_bet_participants_who_paid_for ON bet_participants(who_paid_for);

-- Create view for debt tracking
CREATE VIEW v_debt_summary AS
SELECT 
  payer.id as payer_id,
  payer.name as payer_name,
  participant.id as participant_id,
  participant.name as participant_name,
  COUNT(*) as total_bets,
  SUM(bp.stake) as total_staked,
  SUM(bp.payout_due) as total_payout_due,
  SUM(
    CASE 
      WHEN b.status = 'won' THEN bp.payout_due - bp.stake
      WHEN b.status IN ('lost') THEN -bp.stake
      WHEN b.status IN ('void', 'push') THEN 0
      ELSE 0
    END
  ) as net_amount,
  SUM(
    CASE 
      WHEN b.status IN ('won', 'lost', 'void', 'push') AND NOT bp.is_paid THEN
        CASE 
          WHEN b.status = 'won' THEN bp.payout_due - bp.stake
          WHEN b.status = 'lost' THEN -bp.stake
          ELSE 0
        END
      ELSE 0
    END
  ) as outstanding_debt
FROM bet_participants bp
JOIN users payer ON payer.id = bp.who_paid_for
JOIN users participant ON participant.id = bp.user_id
JOIN bets b ON b.id = bp.bet_id
WHERE bp.who_paid_for != bp.user_id  -- Only show when someone else paid
GROUP BY payer.id, payer.name, participant.id, participant.name;

-- Function to calculate who owes what to whom
CREATE OR REPLACE FUNCTION get_debt_summary(payer_user_id uuid DEFAULT NULL)
RETURNS TABLE (
  participant_name text,
  participant_email text,
  total_bets bigint,
  total_staked numeric,
  net_amount numeric,
  outstanding_debt numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ds.participant_name,
    u.email as participant_email,
    ds.total_bets,
    ds.total_staked,
    ds.net_amount,
    ds.outstanding_debt
  FROM v_debt_summary ds
  JOIN users u ON u.id = ds.participant_id
  WHERE (payer_user_id IS NULL OR ds.payer_id = payer_user_id)
    AND ds.outstanding_debt != 0  -- Only show outstanding debts
  ORDER BY ds.outstanding_debt DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;