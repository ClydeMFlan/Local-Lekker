-- Check RLS policies for UPDATE on deal_authorizations table

-- 1. Check all policies on deal_authorizations
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'deal_authorizations'
ORDER BY cmd;

-- 2. Check if RLS is enabled
SELECT 
  schemaname,
  tablename,
  rowsecurity
FROM pg_tables
WHERE tablename = 'deal_authorizations';

-- 3. Test if current user can UPDATE payment_completed_at
-- Replace 'YOUR_DEAL_ID' with the actual deal ID you're testing with
-- This will show the exact error if RLS is blocking
-- UPDATE deal_authorizations 
-- SET payment_completed_at = NOW()
-- WHERE id = 'YOUR_DEAL_ID';
