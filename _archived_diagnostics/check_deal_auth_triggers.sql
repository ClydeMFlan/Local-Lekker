-- Check for triggers on deal_authorizations table

SELECT 
  trigger_name,
  event_manipulation,
  action_statement,
  action_timing
FROM information_schema.triggers
WHERE event_object_table = 'deal_authorizations'
ORDER BY trigger_name;

-- Get full trigger definitions
SELECT 
  tgname AS trigger_name,
  pg_get_triggerdef(oid) AS trigger_definition
FROM pg_trigger
WHERE tgrelid = 'deal_authorizations'::regclass
  AND tgisinternal = false;
