-- =====================================================
-- AUTOMATED TEST: Admin Deletion Fix
-- =====================================================
-- This creates a test member, deletes their data,
-- and verifies auth.users is preserved (proving the fix works)
-- =====================================================

DO $$
DECLARE
  test_user_id UUID;
  test_email TEXT := 'test_delete_' || floor(random() * 10000)::text || '@test.com';
  deletion_result JSON;
  profile_count INT;
  auth_count INT;
  subscription_count INT;
  membership_count INT;
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'AUTOMATED ADMIN DELETION TEST';
  RAISE NOTICE '========================================';
  
  -- Create test user
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password, email_confirmed_at,
    created_at, updated_at, raw_app_meta_data, raw_user_meta_data, aud, role
  ) VALUES (
    gen_random_uuid(), '00000000-0000-0000-0000-000000000000', test_email,
    crypt('test', gen_salt('bf')), now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"user_type":"member"}'::jsonb, 'authenticated', 'authenticated'
  ) RETURNING id INTO test_user_id;

  INSERT INTO profiles (id, email, name, role, created_at, updated_at)
  VALUES (test_user_id, test_email, 'Test Member', 'member', now(), now());

  -- Create subscription with required plan_type
  INSERT INTO subscriptions (id, user_id, plan_type, status, created_at, updated_at)
  VALUES (gen_random_uuid(), test_user_id, 'basic', 'active', now(), now());

  -- Create membership (no id column, user_id is primary key)
  INSERT INTO memberships (user_id, role, gateway, created_at, updated_at)
  VALUES (test_user_id, 'member', 'test', now(), now());

  RAISE NOTICE 'Created test member: % (%)', test_email, test_user_id;

  -- Verify data exists before deletion
  SELECT COUNT(*) INTO subscription_count FROM subscriptions WHERE user_id = test_user_id;
  SELECT COUNT(*) INTO membership_count FROM memberships WHERE user_id = test_user_id;
  RAISE NOTICE 'Subscriptions before deletion: %', subscription_count;
  RAISE NOTICE 'Memberships before deletion: %', membership_count;

  -- Test deletion
  SELECT admin_delete_member_data(test_user_id) INTO deletion_result;
  RAISE NOTICE 'Deletion result: %', deletion_result;

  -- Verify profile is deleted
  SELECT COUNT(*) INTO profile_count FROM profiles WHERE id = test_user_id;
  IF profile_count = 0 THEN
    RAISE NOTICE '✓ Profile deleted successfully';
  ELSE
    RAISE EXCEPTION '✗ Profile still exists!';
  END IF;

  -- Verify subscriptions are deleted
  SELECT COUNT(*) INTO subscription_count FROM subscriptions WHERE user_id = test_user_id;
  IF subscription_count = 0 THEN
    RAISE NOTICE '✓ Subscriptions deleted successfully';
  ELSE
    RAISE EXCEPTION '✗ Subscriptions still exist!';
  END IF;

  -- Verify memberships are deleted
  SELECT COUNT(*) INTO membership_count FROM memberships WHERE user_id = test_user_id;
  IF membership_count = 0 THEN
    RAISE NOTICE '✓ Memberships deleted successfully';
  ELSE
    RAISE EXCEPTION '✗ Memberships still exist!';
  END IF;

  -- Verify auth.users still exists (KEY TEST)
  SELECT COUNT(*) INTO auth_count FROM auth.users WHERE id = test_user_id;
  IF auth_count = 1 THEN
    RAISE NOTICE '✓ Auth user still exists (CORRECT - proves fix works!)';
  ELSE
    RAISE EXCEPTION '✗ Auth user was deleted (WRONG - function should not delete auth.users)';
  END IF;

  -- Cleanup
  DELETE FROM auth.users WHERE id = test_user_id;
  RAISE NOTICE '✓ Test cleanup complete';
  
  RAISE NOTICE '========================================';
  RAISE NOTICE 'TEST PASSED: Function works correctly!';
  RAISE NOTICE 'Data deleted, auth.users preserved';
  RAISE NOTICE '========================================';
END $$;
