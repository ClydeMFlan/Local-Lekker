-- ============================================
-- COMPREHENSIVE TABLE COLUMN CHECK
-- Schema-agnostic version - discovers columns dynamically
-- ============================================

-- ============================================
-- PART 1: LIST ALL COLUMNS IN EACH TABLE
-- ============================================
SELECT '=== PART 1: ALL COLUMNS IN EACH TABLE ===' as info;
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'deal_authorizations',
    'deal_receipts',
    'virtual_receipts',
    'trusted_partner_bank_accounts',
    'profiles',
    'businesses',
    'memberships',
    'processed_bills',
    'notifications',
    'trusted_partners',
    'trusted_partner_discounts'
  )
ORDER BY table_name, ordinal_position;

-- ============================================
-- PART 2: COUNT ROWS IN EACH TABLE
-- ============================================
SELECT '=== PART 2: ROW COUNTS ===' as info;
SELECT 'deal_authorizations' as table_name, COUNT(*) as total_rows FROM deal_authorizations
UNION ALL
SELECT 'deal_receipts', COUNT(*) FROM deal_receipts
UNION ALL
SELECT 'virtual_receipts', COUNT(*) FROM virtual_receipts
UNION ALL
SELECT 'trusted_partner_bank_accounts', COUNT(*) FROM trusted_partner_bank_accounts
UNION ALL
SELECT 'profiles', COUNT(*) FROM profiles
UNION ALL
SELECT 'businesses', COUNT(*) FROM businesses
UNION ALL
SELECT 'memberships', COUNT(*) FROM memberships
UNION ALL
SELECT 'processed_bills', COUNT(*) FROM processed_bills
UNION ALL
SELECT 'notifications', COUNT(*) FROM notifications
UNION ALL
SELECT 'trusted_partners', COUNT(*) FROM trusted_partners
UNION ALL
SELECT 'trusted_partner_discounts', COUNT(*) FROM trusted_partner_discounts
ORDER BY table_name;

-- ============================================
-- PART 3: SAMPLE DATA FROM KEY TABLES
-- ============================================

SELECT '=== PART 3: SAMPLE DATA ===' as info;

SELECT '--- DEAL_AUTHORIZATIONS ---' as info;
SELECT * FROM deal_authorizations ORDER BY created_at DESC LIMIT 3;

SELECT '--- DEAL_RECEIPTS ---' as info;
SELECT * FROM deal_receipts ORDER BY created_at DESC LIMIT 3;

SELECT '--- VIRTUAL_RECEIPTS ---' as info;
SELECT * FROM virtual_receipts ORDER BY created_at DESC LIMIT 3;

SELECT '--- PROFILES ---' as info;
SELECT * FROM profiles ORDER BY created_at DESC LIMIT 3;

SELECT '--- BUSINESSES ---' as info;
SELECT * FROM businesses ORDER BY created_at DESC LIMIT 3;

SELECT '--- TRUSTED_PARTNER_BANK_ACCOUNTS ---' as info;
SELECT * FROM trusted_partner_bank_accounts ORDER BY created_at DESC LIMIT 3;

-- ============================================
-- PART 4: NULL VALUE ANALYSIS (KEY FIELDS ONLY)
-- ============================================

SELECT '=== PART 4: NULL VALUE ANALYSIS ===' as info;

SELECT '--- DEAL_AUTHORIZATIONS NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(member_id) as member_id_nulls,
  COUNT(*) - COUNT(trusted_partner_id) as trusted_partner_id_nulls,
  COUNT(*) - COUNT(discount_id) as discount_id_nulls,
  COUNT(*) - COUNT(status) as status_nulls,
  COUNT(*) - COUNT(amount) as amount_nulls,
  COUNT(*) - COUNT(approved_at) as approved_at_nulls,
  COUNT(*) - COUNT(completed_at) as completed_at_nulls
FROM deal_authorizations;

SELECT '--- DEAL_RECEIPTS NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(deal_authorization_id) as deal_authorization_id_nulls,
  COUNT(*) - COUNT(member_id) as member_id_nulls,
  COUNT(*) - COUNT(trusted_partner_id) as trusted_partner_id_nulls,
  COUNT(*) - COUNT(business_id) as business_id_nulls,
  COUNT(*) - COUNT(receipt_number) as receipt_number_nulls,
  COUNT(*) - COUNT(amount) as amount_nulls,
  COUNT(*) - COUNT(business_name) as business_name_nulls,
  COUNT(*) - COUNT(discount_name) as discount_name_nulls,
  COUNT(*) - COUNT(member_name) as member_name_nulls,
  COUNT(*) - COUNT(member_email) as member_email_nulls
FROM deal_receipts;

SELECT '--- VIRTUAL_RECEIPTS NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(deal_authorization_id) as deal_authorization_id_nulls,
  COUNT(*) - COUNT(receipt_number) as receipt_number_nulls,
  COUNT(*) - COUNT(receipt_data) as receipt_data_nulls,
  COUNT(*) - COUNT(qr_code) as qr_code_nulls
FROM virtual_receipts;

SELECT '--- PROFILES NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(name) as name_nulls,
  COUNT(*) - COUNT(surname) as surname_nulls,
  COUNT(*) - COUNT(email) as email_nulls,
  COUNT(*) - COUNT(role) as role_nulls,
  COUNT(*) - COUNT(contact) as contact_nulls
FROM profiles;

SELECT '--- BUSINESSES NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(name) as name_nulls,
  COUNT(*) - COUNT(category) as category_nulls,
  COUNT(*) - COUNT(address) as address_nulls,
  COUNT(*) - COUNT(contact_email) as contact_email_nulls,
  COUNT(*) - COUNT(contact_number) as contact_number_nulls
FROM businesses;

SELECT '--- TRUSTED_PARTNER_BANK_ACCOUNTS NULL COUNTS ---' as info;
SELECT 
  COUNT(*) as total_rows,
  COUNT(*) - COUNT(id) as id_nulls,
  COUNT(*) - COUNT(user_id) as user_id_nulls,
  COUNT(*) - COUNT(account_holder_name) as account_holder_name_nulls,
  COUNT(*) - COUNT(bank_name) as bank_name_nulls,
  COUNT(*) - COUNT(account_number) as account_number_nulls
FROM trusted_partner_bank_accounts;

-- ============================================
-- PART 5: IDENTIFY PROBLEMATIC RECORDS
-- ============================================

SELECT '=== PART 5: PROBLEMATIC RECORDS ===' as info;

SELECT '--- DEAL_AUTHORIZATIONS WITH MISSING DATA ---' as info;
SELECT 
  id,
  member_id,
  trusted_partner_id,
  discount_id,
  amount,
  status,
  created_at
FROM deal_authorizations
WHERE member_id IS NULL 
   OR trusted_partner_id IS NULL 
   OR discount_id IS NULL 
   OR amount IS NULL
ORDER BY created_at DESC
LIMIT 10;

SELECT '--- DEAL_RECEIPTS WITH MISSING DATA ---' as info;
SELECT 
  id,
  deal_authorization_id,
  member_id,
  trusted_partner_id,
  business_id,
  receipt_number,
  business_name,
  discount_name,
  member_name,
  member_email,
  created_at
FROM deal_receipts
WHERE deal_authorization_id IS NULL 
   OR member_id IS NULL 
   OR trusted_partner_id IS NULL 
   OR business_id IS NULL
   OR business_name IS NULL
   OR discount_name IS NULL
   OR member_name IS NULL
   OR member_email IS NULL
ORDER BY created_at DESC
LIMIT 10;

SELECT '--- PROFILES WITH MISSING DATA ---' as info;
SELECT 
  id,
  name,
  surname,
  email,
  role,
  contact,
  created_at
FROM profiles
WHERE name IS NULL 
   OR surname IS NULL 
   OR email IS NULL 
   OR role IS NULL
   OR contact IS NULL
ORDER BY created_at DESC
LIMIT 10;

SELECT '=== ANALYSIS COMPLETE ===' as info;
