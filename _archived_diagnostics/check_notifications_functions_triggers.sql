-- Check if there's a Postgres function for inserting notifications
-- Functions run with SECURITY DEFINER and bypass RLS

SELECT 
    p.proname AS function_name,
    pg_catalog.pg_get_functiondef(p.oid) AS function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
  AND p.proname LIKE '%notification%'
ORDER BY p.proname;

-- Also check if there are any triggers on notifications
SELECT 
    tgname AS trigger_name,
    tgenabled AS enabled,
    pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'notifications'::regclass
  AND tgisinternal = false;
