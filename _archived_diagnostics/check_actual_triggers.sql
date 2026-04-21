
-- Check what triggers are actually installed on auth.users
SELECT 
    trigger_name,
    event_manipulation,
    event_object_schema,
    event_object_table,
    action_statement,
    action_timing,
    action_orientation
FROM information_schema.triggers 
WHERE event_object_table = 'users' 
AND event_object_schema = 'auth'
ORDER BY trigger_name;

-- Check if our trigger function exists
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'handle_new_user_role_assignment';

-- Check if there's a different trigger function being used
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'create_profile_from_auth';

-- Check all triggers in the database
SELECT 
    trigger_schema,
    trigger_name,
    event_object_schema,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_name LIKE '%user%' OR trigger_name LIKE '%profile%' OR trigger_name LIKE '%auth%'
ORDER BY trigger_name;

