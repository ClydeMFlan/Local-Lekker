-- Check if RLS is enabled on notifications table
SELECT relname, relrowsecurity, relforcerowsecurity
FROM pg_class
WHERE relname = 'notifications';

-- Check ALL policies on notifications table
SELECT 
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- Test if authenticated user can insert
-- First, check current auth status
SELECT auth.uid() as current_user_id;

-- Try to verify the INSERT would work
EXPLAIN (VERBOSE ON, COSTS OFF)
INSERT INTO notifications (user_id, title, message, type)
VALUES ('78e67dc8-583b-4fe0-84e6-aa4d0c55a92e', 'Test', 'Test message', 'info');
