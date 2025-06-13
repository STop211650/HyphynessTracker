-- Helper function to calculate payout_due when a bet is settled
CREATE OR REPLACE FUNCTION calculate_payouts()
RETURNS TRIGGER AS $$
BEGIN
  -- Only calculate if bet is being settled (status changing from pending)
  IF NEW.status != 'pending' AND OLD.status = 'pending' THEN
    -- Update payout_due for all participants based on bet outcome
    UPDATE bet_participants
    SET payout_due = CASE
      WHEN NEW.status = 'won' THEN 
        -- Pro-rata share of winnings: (stake / risk) * to_win
        ROUND((stake / NEW.risk) * NEW.to_win, 2)
      WHEN NEW.status IN ('void', 'push') THEN 
        -- Return original stake
        stake
      ELSE 
        -- Lost bet, no payout
        0
    END
    WHERE bet_id = NEW.id;
    
    -- Update the total payout on the bet
    UPDATE bets
    SET payout_total = (
      SELECT SUM(payout_due) 
      FROM bet_participants 
      WHERE bet_id = NEW.id
    )
    WHERE id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically calculate payouts when bet is settled
CREATE TRIGGER calculate_payouts_on_settle
  AFTER UPDATE OF status ON bets
  FOR EACH ROW
  EXECUTE FUNCTION calculate_payouts();

-- Helper function to validate stake sum equals risk
CREATE OR REPLACE FUNCTION validate_stake_sum()
RETURNS TRIGGER AS $$
DECLARE
  total_stake numeric;
  bet_risk numeric;
BEGIN
  -- Get the total stake for this bet
  SELECT SUM(stake) INTO total_stake
  FROM bet_participants
  WHERE bet_id = NEW.bet_id;
  
  -- Get the risk amount from the bet
  SELECT risk INTO bet_risk
  FROM bets
  WHERE id = NEW.bet_id;
  
  -- Check if stakes sum to risk (with small tolerance for rounding)
  IF ABS(total_stake - bet_risk) > 0.01 THEN
    RAISE EXCEPTION 'Total stakes (%) must equal bet risk (%)', total_stake, bet_risk;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to validate stakes
CREATE TRIGGER validate_stakes
  AFTER INSERT OR UPDATE ON bet_participants
  FOR EACH ROW
  EXECUTE FUNCTION validate_stake_sum();

-- Function to get user's net position
CREATE OR REPLACE FUNCTION get_user_net_position(user_uuid uuid)
RETURNS TABLE (
  total_staked numeric,
  total_returned numeric,
  total_pending numeric,
  net_profit numeric,
  outstanding_balance numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(SUM(bp.stake), 0) as total_staked,
    COALESCE(SUM(CASE WHEN b.status = 'won' THEN bp.payout_due ELSE 0 END), 0) as total_returned,
    COALESCE(SUM(CASE WHEN b.status = 'pending' THEN bp.stake ELSE 0 END), 0) as total_pending,
    COALESCE(SUM(
      CASE 
        WHEN b.status = 'won' THEN bp.payout_due - bp.stake
        WHEN b.status IN ('lost') THEN -bp.stake
        WHEN b.status IN ('void', 'push') THEN 0
        ELSE 0
      END
    ), 0) as net_profit,
    COALESCE(SUM(
      CASE 
        WHEN b.status IN ('won', 'lost') AND NOT bp.is_paid THEN
          CASE 
            WHEN b.status = 'won' THEN bp.payout_due - bp.stake
            ELSE -bp.stake
          END
        ELSE 0
      END
    ), 0) as outstanding_balance
  FROM bet_participants bp
  JOIN bets b ON b.id = bp.bet_id
  WHERE bp.user_id = user_uuid;
END;
$$ LANGUAGE plpgsql;