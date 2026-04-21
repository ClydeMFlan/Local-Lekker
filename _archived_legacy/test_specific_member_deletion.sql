-- =====================================================
-- TEST: Delete specific member via admin function
-- =====================================================
-- Testing deletion of user: 09e95df7-0500-437a-b732-15a7789b390b
-- Email: thecraftsmanel@gmail.com
-- =====================================================

DO $$
DECLARE
  target_user_id UUID := '09e95df7-0500-437a-b732-15a7789b390b';
  expected_email TEXT := 'thecraftsmanel@gmail.com';
  deletion_result JSON;
  profile_exists BOOLEAN;
  auth_exists BOOLEAN;
  user_email TEXT;
  user_name TEXT;
  user_role TEXT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TESTING MEMBER DELETION';
  RAISE NOTICE 'User ID: %', target_user_id;
  RAISE NOTICE 'Expected Email: %', expected_email;
  RAISE NOTICE '========================================';
  
  -- Check if user exists and get details
  SELECT email, name, role INTO user_email, user_name, user_role
  FROM profiles
  WHERE id = target_user_id;
  
  IF NOT FOUND THEN
    RAISE NOTICE '❌ User not found in profiles table';
    RAISE NOTICE 'Checking auth.users...';
    
    SELECT email INTO user_email
    FROM auth.users
    WHERE id = target_user_id;
    
    IF FOUND THEN
      RAISE NOTICE '⚠️  User exists in auth.users but not in profiles';
      RAISE NOTICE 'Email: %', user_email;
    ELSE
      RAISE NOTICE '❌ User does not exist in auth.users either';
    END IF;
    
    RETURN;
  END IF;
  
  RAISE NOTICE 'Found user:';
  RAISE NOTICE '  Email: %', user_email;
  RAISE NOTICE '  Name: %', user_name;
  RAISE NOTICE '  Role: %', user_role;
  
  -- Verify email matches
  IF user_email = expected_email THEN
    RAISE NOTICE '  ✓ Email matches expected';
  ELSE
    RAISE NOTICE '  ⚠️  Email does not match! Expected: %', expected_email;
  END IF;
  RAISE NOTICE '';
  
  -- Verify role is member
  IF user_role != 'member' THEN
    RAISE NOTICE '⚠️  WARNING: User role is "%" not "member"', user_role;
    RAISE NOTICE 'This function only works for members';
    RETURN;
  END IF;
  
  -- Show related data counts before deletion
  RAISE NOTICE 'Related data before deletion:';
  RAISE NOTICE '  Subscriptions: %', (SELECT COUNT(*) FROM subscriptions WHERE user_id = target_user_id);
  RAISE NOTICE '  Memberships: %', (SELECT COUNT(*) FROM memberships WHERE user_id = target_user_id);
  RAISE NOTICE '  QR Codes: %', (SELECT COUNT(*) FROM user_qr_codes WHERE user_id = target_user_id);
  RAISE NOTICE '  Payments: %', (SELECT COUNT(*) FROM payments WHERE user_id = target_user_id);
  RAISE NOTICE '  Notifications: %', (SELECT COUNT(*) FROM notifications WHERE user_id = target_user_id);
  RAISE NOTICE '  Member Receipts: %', (SELECT COUNT(*) FROM member_receipts WHERE member_id = target_user_id);
  RAISE NOTICE '  Deal Authorizations: %', (SELECT COUNT(*) FROM deal_authorizations WHERE member_id = target_user_id);
  RAISE NOTICE '';
  
  -- Perform deletion
  RAISE NOTICE 'Calling admin_delete_member_data()...';
  SELECT admin_delete_member_data(target_user_id) INTO deletion_result;
  RAISE NOTICE 'Result: %', deletion_result;
  RAISE NOTICE '';
  
  -- Verify profile is deleted
  SELECT EXISTS(SELECT 1 FROM profiles WHERE id = target_user_id) INTO profile_exists;
  IF NOT profile_exists THEN
    RAISE NOTICE '✓ Profile deleted successfully';
  ELSE
    RAISE NOTICE '✗ Profile still exists!';
  END IF;
  
  -- Verify auth.users still exists (this is correct behavior)
  SELECT EXISTS(SELECT 1 FROM auth.users WHERE id = target_user_id) INTO auth_exists;
  IF auth_exists THEN
    RAISE NOTICE '✓ Auth user still exists (will be deleted by app via Admin API)';
  ELSE
    RAISE NOTICE '⚠️  Auth user already deleted';
  END IF;
  
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'DELETION TEST COMPLETE';
  RAISE NOTICE 'Next step: App should call supabase.auth.admin.deleteUser()';
  RAISE NOTICE '========================================';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE '========================================';
    RAISE NOTICE '❌ ERROR: %', SQLERRM;
    RAISE NOTICE '========================================';
END $$;
