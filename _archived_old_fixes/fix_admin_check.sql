-- Fix admin check function to use email instead of non-existent admin_dashboard table
-- This matches the logic in the Flutter app and Edge Function

CREATE OR REPLACE FUNCTION is_admin(user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_email TEXT;
BEGIN
  -- Get the user's email from profiles
  SELECT email INTO user_email
  FROM profiles
  WHERE id = user_id;

  -- Check if email is the admin email (matches Flutter app logic)
  RETURN user_email = 'admin@locallekker.com';
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION is_admin(UUID) TO authenticated;