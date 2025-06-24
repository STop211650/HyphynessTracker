-- Bootstrap script to create the first super admin
-- This will be run manually after you create your account

-- Function to bootstrap first super admin
-- Usage: SELECT bootstrap_first_admin('your_email@example.com');
CREATE OR REPLACE FUNCTION bootstrap_first_admin(admin_email text)
RETURNS text AS $$
DECLARE
  admin_count integer;
  user_id uuid;
BEGIN
  -- Check if any super admins already exist
  SELECT COUNT(*) INTO admin_count FROM users WHERE is_super_admin = true;
  
  IF admin_count > 0 THEN
    RETURN 'Super admin already exists. Cannot bootstrap.';
  END IF;
  
  -- Find user by email
  SELECT id INTO user_id FROM users WHERE email = admin_email;
  
  IF user_id IS NULL THEN
    RETURN 'User not found with email: ' || admin_email;
  END IF;
  
  -- Make them super admin
  UPDATE users SET is_super_admin = true WHERE id = user_id;
  
  RETURN 'Successfully promoted ' || admin_email || ' to super admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comment with instructions
COMMENT ON FUNCTION bootstrap_first_admin(text) IS 
'Bootstrap function to create the first super admin. 
Only works if no super admins exist yet.
Usage: SELECT bootstrap_first_admin(''your_email@example.com'');';