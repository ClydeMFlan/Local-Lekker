-- Check if updated_at is null
SELECT 
  id,
  created_at,
  updated_at,
  CASE 
    WHEN updated_at IS NULL THEN 'NULL'
    ELSE 'NOT NULL'
  END as updated_at_status
FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 10;
