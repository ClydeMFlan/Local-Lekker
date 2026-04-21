-- DANGER: This will delete ALL receipts from ALL users in the system
-- Use this only for development/testing, NEVER in production with real user data

-- Step 1: Check what will be deleted
SELECT 
  'deal_receipts' as table_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT member_id) as unique_members
FROM deal_receipts
UNION ALL
SELECT 
  'virtual_receipts' as table_name,
  COUNT(*) as total_records,
  NULL as unique_members
FROM virtual_receipts
UNION ALL
SELECT 
  'deal_authorizations' as table_name,
  COUNT(*) as total_records,
  COUNT(DISTINCT member_id) as unique_members
FROM deal_authorizations;

-- Step 2: Show sample receipts that will be deleted
SELECT 
  'deal_receipts' as source,
  receipt_number,
  member_id,
  business_name,
  created_at
FROM deal_receipts
ORDER BY created_at DESC
LIMIT 5;

SELECT 
  'virtual_receipts' as source,
  receipt_number,
  deal_authorization_id,
  created_at
FROM virtual_receipts
ORDER BY created_at DESC
LIMIT 5;

-- Step 3: DELETE ALL virtual_receipts (must be first due to foreign key)
DELETE FROM virtual_receipts;

-- Step 4: DELETE ALL deal_receipts
DELETE FROM deal_receipts;

-- Step 5: DELETE ALL deal_authorizations
DELETE FROM deal_authorizations;

-- Step 6: Reset sequences (if they exist)
-- Check if sequences exist first
SELECT 
  schemaname,
  sequencename,
  last_value,
  start_value
FROM pg_sequences
WHERE sequencename LIKE '%receipt%'
   OR sequencename LIKE '%authorization%';

-- If sequences exist, reset them:
-- ALTER SEQUENCE deal_receipts_id_seq RESTART WITH 1;
-- ALTER SEQUENCE virtual_receipts_id_seq RESTART WITH 1;
-- ALTER SEQUENCE deal_authorizations_id_seq RESTART WITH 1;

-- Step 7: Verify all receipts are deleted
SELECT 
  'deal_receipts' as table_name,
  COUNT(*) as remaining_records
FROM deal_receipts
UNION ALL
SELECT 
  'virtual_receipts' as table_name,
  COUNT(*) as remaining_records
FROM virtual_receipts
UNION ALL
SELECT 
  'deal_authorizations' as table_name,
  COUNT(*) as remaining_records
FROM deal_authorizations;

-- Step 8: Verify next receipt will start fresh
-- The application logic should generate the next receipt as:
-- - deal_receipts: TP-XXX-00001 (where XXX is business code)
-- - virtual_receipts: VR-00001 or similar pattern
SELECT 
  'deal_receipts max number' as check_type,
  COALESCE(MAX(CAST(SUBSTRING(receipt_number FROM '[0-9]+') AS INTEGER)), 0) as max_value
FROM deal_receipts
UNION ALL
SELECT 
  'virtual_receipts max number' as check_type,
  COALESCE(MAX(CAST(SUBSTRING(receipt_number FROM '[0-9]+') AS INTEGER)), 0) as max_value
FROM virtual_receipts;

-- Expected result: Both should show 0, so next receipt will be 00001
