-- =============================================================================
-- COMPREHENSIVE TABLE & COLUMN VERIFICATION
-- Verify that app code matches database schema
-- =============================================================================

-- 1. TRUSTED_PARTNER_DISCOUNTS TABLE
-- App expects: id, trusted_partner_id, name, description, item_name, item_price, percentage, fixed_amount, is_active, created_at, updated_at
SELECT '=== TRUSTED_PARTNER_DISCOUNTS TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'trusted_partner_id', 'name', 'description', 'item_name', 'item_price', 'percentage', 'is_active', 'created_at', 'updated_at') THEN '✅ REQUIRED'
         WHEN column_name = 'fixed_amount' THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;

-- 2. BUSINESSES TABLE
-- App expects: id, owner_member_id, name, category, verified, created_at, updated_at
SELECT '=== BUSINESSES TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'owner_member_id', 'name') THEN '✅ REQUIRED'
         WHEN column_name IN ('category', 'verified', 'created_at', 'updated_at') THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'businesses'
ORDER BY ordinal_position;

-- 3. DEAL_AUTHORIZATIONS TABLE
-- App expects: id, member_id, trusted_partner_id, discount_id, status, authorization_type, payment_method, amount, notes, rejection_reason, created_at, updated_at, approved_at, completed_at
SELECT '=== DEAL_AUTHORIZATIONS TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'member_id', 'trusted_partner_id', 'discount_id', 'status', 'created_at', 'updated_at') THEN '✅ REQUIRED'
         WHEN column_name IN ('authorization_type', 'payment_method', 'amount', 'notes', 'rejection_reason', 'approved_at', 'completed_at') THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- 4. NOTIFICATIONS TABLE
-- App expects: id, user_id, title, message, type, data, is_read, created_at, updated_at
SELECT '=== NOTIFICATIONS TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'user_id', 'title', 'message', 'type', 'is_read', 'created_at') THEN '✅ REQUIRED'
         WHEN column_name IN ('data', 'updated_at') THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- 5. VIRTUAL_RECEIPTS TABLE
-- App expects: id, deal_authorization_id, receipt_number, receipt_data, qr_code, created_at
SELECT '=== VIRTUAL_RECEIPTS TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'deal_authorization_id', 'receipt_number', 'receipt_data', 'created_at') THEN '✅ REQUIRED'
         WHEN column_name = 'qr_code' THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'virtual_receipts'
ORDER BY ordinal_position;

-- 6. MEMBER_RECEIPTS TABLE
-- App expects: id, member_id, virtual_receipt_id, receipt_type, title, description, amount, business_name, receipt_date, created_at
SELECT '=== MEMBER_RECEIPTS TABLE ===' as check_section;
SELECT column_name, data_type, is_nullable,
       CASE
         WHEN column_name IN ('id', 'member_id', 'receipt_type', 'title', 'receipt_date', 'created_at') THEN '✅ REQUIRED'
         WHEN column_name IN ('virtual_receipt_id', 'description', 'amount', 'business_name') THEN '✅ OPTIONAL'
         ELSE '⚠️  UNEXPECTED'
       END as app_usage
FROM information_schema.columns
WHERE table_name = 'member_receipts'
ORDER BY ordinal_position;

-- 7. SUMMARY REPORT
SELECT '=== VERIFICATION SUMMARY ===' as summary;
SELECT
    'Total tables checked' as metric,
    COUNT(DISTINCT table_name) as value
FROM information_schema.columns
WHERE table_name IN ('trusted_partner_discounts', 'businesses', 'deal_authorizations', 'notifications', 'virtual_receipts', 'member_receipts');

-- Check for missing required columns
SELECT '=== MISSING REQUIRED COLUMNS ===' as alert;
SELECT table_name, 'MISSING: ' || string_agg(missing_column, ', ') as issues
FROM (
    SELECT table_name,
           CASE
             WHEN table_name = 'trusted_partner_discounts' AND column_name NOT IN ('id', 'trusted_partner_id', 'name', 'description', 'item_name', 'item_price', 'percentage', 'fixed_amount', 'is_active', 'created_at', 'updated_at') THEN column_name
             WHEN table_name = 'businesses' AND column_name NOT IN ('id', 'owner_member_id', 'name', 'category', 'verified', 'created_at', 'updated_at') THEN column_name
             WHEN table_name = 'deal_authorizations' AND column_name NOT IN ('id', 'member_id', 'trusted_partner_id', 'discount_id', 'status', 'authorization_type', 'payment_method', 'amount', 'notes', 'rejection_reason', 'created_at', 'updated_at', 'approved_at', 'completed_at') THEN column_name
             WHEN table_name = 'notifications' AND column_name NOT IN ('id', 'user_id', 'title', 'message', 'type', 'data', 'is_read', 'created_at', 'updated_at') THEN column_name
             WHEN table_name = 'virtual_receipts' AND column_name NOT IN ('id', 'deal_authorization_id', 'receipt_number', 'receipt_data', 'qr_code', 'created_at') THEN column_name
             WHEN table_name = 'member_receipts' AND column_name NOT IN ('id', 'member_id', 'virtual_receipt_id', 'receipt_type', 'title', 'description', 'amount', 'business_name', 'receipt_date', 'created_at') THEN column_name
           END as missing_column
    FROM information_schema.columns
    WHERE table_name IN ('trusted_partner_discounts', 'businesses', 'deal_authorizations', 'notifications', 'virtual_receipts', 'member_receipts')
    AND missing_column IS NOT NULL
) t
GROUP BY table_name
HAVING COUNT(*) > 0;