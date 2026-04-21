-- =============================================================================
-- DEBUG NOTIFICATIONS RLS - CHECK ROLE AND POLICY EVALUATION
-- =============================================================================

-- 1. Check what role is being used for the connection
SELECT current_user, session_user;

-- 2. Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE tablename = 'notifications';

-- 3. Check ALL policies on notifications (not just INSERT)
SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY cmd, policyname;

-- 4. Check if the policy applies to 'public' role or 'authenticated' role
SELECT 
    policyname,
    cmd,
    roles,
    CASE 
        WHEN 'authenticated' = ANY(roles) THEN 'YES - authenticated role'
        WHEN 'public' = ANY(roles) THEN 'YES - public role'
        ELSE 'NO - role mismatch'
    END as "Applies to authenticated users"
FROM pg_policies
WHERE tablename = 'notifications' AND cmd = 'INSERT';

-- 5. Try to manually test insert (will fail if RLS blocks it)
-- This simulates what the app is trying to do
DO $$
BEGIN
    INSERT INTO notifications (user_id, title, message, type)
    VALUES (
        '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e',
        'Test Notification',
        'Testing RLS policy',
        'test'
    );
    RAISE NOTICE 'SUCCESS: Insert worked! RLS policy is allowing inserts.';
    -- Clean up the test
    DELETE FROM notifications WHERE type = 'test' AND title = 'Test Notification';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'FAILED: RLS is blocking inserts. Error: %', SQLERRM;
END $$;
