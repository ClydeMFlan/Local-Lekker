-- Check the status constraint on deal_authorizations table

-- 1. Get the constraint definition
SELECT
  conname AS constraint_name,
  pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'deal_authorizations'::regclass
  AND conname LIKE '%status%';

-- 2. Check current status values in the table
SELECT 
  status,
  COUNT(*) as count
FROM deal_authorizations
GROUP BY status
ORDER BY count DESC;

-- 3. Check the specific deal that's failing
SELECT 
  id,
  status,
  payment_method,
  payment_completed_at,
  approved_at,
  completed_at
FROM deal_authorizations
WHERE status = 'approved'
LIMIT 5;
