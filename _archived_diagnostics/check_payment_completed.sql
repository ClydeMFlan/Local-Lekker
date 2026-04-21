-- Check if payment_completed_at is being set
SELECT 
  id,
  status,
  payment_method,
  amount,
  created_at,
  approved_at,
  payment_completed_at,
  completed_at,
  updated_at
FROM deal_authorizations
WHERE status = 'approved'
ORDER BY updated_at DESC
LIMIT 10;

-- Check if ANY deals have payment_completed_at set
SELECT 
  COUNT(*) as total_approved,
  COUNT(payment_completed_at) as with_payment_timestamp
FROM deal_authorizations
WHERE status = 'approved';

-- Check RLS policies on deal_authorizations table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'deal_authorizations';
