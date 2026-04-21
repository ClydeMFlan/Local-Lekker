
-- Check if the trigger function is actually installed and working
SELECT 
    trigger_name,
    event_manipulation,
    event_object_schema,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
AND event_object_schema = 'auth';

-- Check the current trigger function definition
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'handle_new_user_role_assignment';

