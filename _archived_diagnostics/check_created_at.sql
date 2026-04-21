-- Check if created_at is null (it shouldn't be, but let's verify)
SELECT 
  id,
  created_at,
  CASE 
    WHEN created_at IS NULL THEN 'NULL'
    ELSE 'NOT NULL'
  END as created_at_status
FROM deal_authorizations
ORDER BY created_at DESC NULLS LAST
LIMIT 10;
