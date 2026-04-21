-- Check RLS policies for virtual_receipts and deal_receipts

-- 1. Check virtual_receipts INSERT policy
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  with_check
FROM pg_policies
WHERE tablename = 'virtual_receipts'
AND cmd = 'INSERT';

-- 2. Check deal_receipts INSERT policy
SELECT 
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  with_check
FROM pg_policies
WHERE tablename = 'deal_receipts'
AND cmd = 'INSERT';

-- 3. Check if ANY virtual_receipts exist
SELECT COUNT(*) as total_virtual_receipts FROM virtual_receipts;

-- 4. Check if ANY deal_receipts exist
SELECT COUNT(*) as total_deal_receipts FROM deal_receipts;

-- 5. Try to manually insert a test receipt to see the exact error
-- (This will fail but show us the RLS error)
INSERT INTO virtual_receipts (
  deal_authorization_id,
  receipt_data,
  qr_code
) VALUES (
  '27389bc0-6fb2-4415-874b-bb02e5397d79',
  '{"test": "data"}'::jsonb,
  'TEST-QR'
);
-- Expected: RLS violation or success
