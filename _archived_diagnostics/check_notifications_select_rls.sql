-- Check SELECT policies on notifications table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual as using_expression,
    with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND cmd = 'SELECT'
ORDER BY policyname;

-- Check what happens when we try to select a notification
-- This simulates what the app is doing after creating the notification
SET ROLE authenticated;
SET request.jwt.claims TO '{"sub": "6c815ef9-5e8a-498b-927c-9d807421f791", "role": "authenticated"}';

-- Try to select the test notification
SELECT id, user_id, title, created_at 
FROM notifications 
WHERE title = 'Test Notification' 
ORDER BY created_at DESC 
LIMIT 1;
