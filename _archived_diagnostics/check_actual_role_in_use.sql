-- =============================================================================
-- CHECK WHAT ROLE IS BEING USED BY THE APP
-- =============================================================================

-- Check current role
SELECT 
    '=== Current Session Info ===' as info,
    current_user as current_user,
    session_user as session_user,
    current_role as current_role;

-- Check auth context (what the app sees)
SELECT 
    '=== Auth Context ===' as info,
    auth.uid() as user_id,
    auth.role() as role,
    auth.email() as email;

-- Check notification policies
SELECT 
    '=== Notification Policies ===' as info,
    policyname,
    cmd,
    permissive,
    roles,
    qual::text as using_clause,
    with_check::text as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- Simulate what the app does - try inserting as different roles
SET ROLE anon;
SELECT '=== Testing as anon role ===' as info;
SELECT current_role;

-- Reset
RESET ROLE;
SELECT '=== Back to default ===' as info;
