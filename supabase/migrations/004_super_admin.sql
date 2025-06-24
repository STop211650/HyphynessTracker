-- Add super admin functionality

-- Add super admin flag to users table
ALTER TABLE users ADD COLUMN is_super_admin boolean DEFAULT false;

-- Create admin invite tokens table
CREATE TABLE admin_invites (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  email text NOT NULL,
  name text NOT NULL,
  token text UNIQUE NOT NULL,
  created_by uuid REFERENCES users(id) NOT NULL,
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  used_at timestamptz,
  created_at timestamptz DEFAULT now()
);

-- Add indexes
CREATE INDEX idx_admin_invites_token ON admin_invites(token);
CREATE INDEX idx_admin_invites_email ON admin_invites(email);
CREATE INDEX idx_users_super_admin ON users(is_super_admin);

-- Update RLS policies to allow super admin access

-- Super admin can view all users
CREATE POLICY "Super admins can view all users" ON users
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can update any user
CREATE POLICY "Super admins can update any user" ON users
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can view all bets
CREATE POLICY "Super admins can view all bets" ON bets
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can create/update any bet
CREATE POLICY "Super admins can manage all bets" ON bets
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can view all bet legs
CREATE POLICY "Super admins can view all bet legs" ON bet_legs
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can manage all bet legs
CREATE POLICY "Super admins can manage all bet legs" ON bet_legs
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can view all bet participants
CREATE POLICY "Super admins can view all bet participants" ON bet_participants
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can manage all bet participants
CREATE POLICY "Super admins can manage all bet participants" ON bet_participants
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can view all payments
CREATE POLICY "Super admins can view all payments" ON payments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Super admin can create any payment
CREATE POLICY "Super admins can create any payment" ON payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Admin invites policies
CREATE POLICY "Super admins can manage invites" ON admin_invites
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM users u 
      WHERE u.id = auth.uid() AND u.is_super_admin = true
    )
  );

-- Enable RLS on admin_invites
ALTER TABLE admin_invites ENABLE ROW LEVEL SECURITY;

-- Function to check if user is super admin
CREATE OR REPLACE FUNCTION is_super_admin(user_uuid uuid DEFAULT auth.uid())
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users 
    WHERE id = user_uuid AND is_super_admin = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to promote user to super admin (only callable by existing super admin)
CREATE OR REPLACE FUNCTION promote_to_super_admin(target_user_id uuid)
RETURNS boolean AS $$
BEGIN
  -- Check if current user is super admin
  IF NOT is_super_admin() THEN
    RAISE EXCEPTION 'Only super admins can promote users';
  END IF;
  
  UPDATE users 
  SET is_super_admin = true 
  WHERE id = target_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin dashboard view
CREATE VIEW v_admin_dashboard AS
SELECT 
  (SELECT COUNT(*) FROM users) as total_users,
  (SELECT COUNT(*) FROM users WHERE is_super_admin = true) as total_admins,
  (SELECT COUNT(*) FROM bets) as total_bets,
  (SELECT COUNT(*) FROM bets WHERE status = 'pending') as pending_bets,
  (SELECT COUNT(*) FROM bets WHERE status = 'won') as won_bets,
  (SELECT COUNT(*) FROM bets WHERE status = 'lost') as lost_bets,
  (SELECT COUNT(*) FROM payments) as total_payments,
  (SELECT COALESCE(SUM(amount), 0) FROM payments) as total_payment_volume,
  (SELECT COUNT(*) FROM admin_invites WHERE used_at IS NULL AND expires_at > now()) as pending_invites;