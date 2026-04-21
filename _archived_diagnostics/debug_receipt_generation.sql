-- Debug: Check if receipts were created after payment

-- 1. Check deal_authorizations for payment_completed_at
SELECT 
  id,
  member_id,
  trusted_partner_id,
  status,
  payment_completed_at,
  created_at,
  amount
FROM deal_authorizations
WHERE member_id = '6c815ef9-5e8a-498b-927c-9d807421f791'  -- Clyde's member ID
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check virtual_receipts table
SELECT 
  id,
  deal_authorization_id,
  receipt_data->>'receipt_number' as receipt_number,
  receipt_data->>'member_name' as member_name,
  receipt_data->>'amount' as amount,
  created_at
FROM virtual_receipts
WHERE receipt_data->>'member_email' = 'clydemflan@gmail.com'
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check deal_receipts table
SELECT 
  id,
  receipt_number,
  member_name,
  business_name,
  amount,
  payment_method,
  created_at
FROM deal_receipts
WHERE member_id = '6c815ef9-5e8a-498b-927c-9d807421f791'
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check RLS policies on deal_receipts for INSERT
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
WHERE tablename = 'deal_receipts'
AND cmd = 'INSERT';

-- 5. Check RLS policies on virtual_receipts for INSERT
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
WHERE tablename = 'virtual_receipts'
AND cmd = 'INSERT';
