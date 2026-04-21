-- Check if the bypass function exists
SELECT 
    proname as function_name,
    pg_get_functiondef(oid) as function_definition
FROM pg_proc
WHERE proname = 'create_notification_bypass_rls';

-- If the function exists, test it
-- If not, you need to run create_notification_bypass_function.sql first
