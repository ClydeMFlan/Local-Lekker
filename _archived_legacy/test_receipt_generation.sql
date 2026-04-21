-- Test script to manually verify receipt generation works

-- 1. Find a recent deal authorization from clydemfaln@gmail.com
SELECT 
  id,
  member_id,
  trusted_partner_id,
  amount,
  approved_at,
  payment_completed_at,
  completed_at,
  created_at
FROM deal_authorizations
WHERE member_id = (SELECT id FROM profiles WHERE email = 'clydemfaln@gmail.com')
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check if payment_completed_at was set (should be NULL if flow didn't work)
-- Note the deal ID from above and check:
-- SELECT payment_completed_at FROM deal_authorizations WHERE id = 'YOUR_DEAL_ID';

-- 3. Check if any receipts were created for this member
SELECT 
  id,
  deal_authorization_id,
  receipt_number,
  created_at
FROM virtual_receipts
WHERE deal_authorization_id IN (
  SELECT id FROM deal_authorizations 
  WHERE member_id = (SELECT id FROM profiles WHERE email = 'clydemfaln@gmail.com')
)
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check deal_receipts table
SELECT 
  id,
  deal_authorization_id,
  receipt_number,
  member_name,
  business_name,
  created_at
FROM deal_receipts
WHERE member_id = (SELECT id FROM profiles WHERE email = 'clydemfaln@gmail.com')
ORDER BY created_at DESC
LIMIT 10;

-- 5. Verify UPDATE policy allows member to update payment_completed_at
-- This will show if the policy is correctly configured
SELECT 
  policyname,
  permissive,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'deal_authorizations'
AND cmd = 'UPDATE';
