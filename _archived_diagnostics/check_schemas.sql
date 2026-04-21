-- =============================================================================
-- CHECK TABLE SCHEMAS INDIVIDUALLY
-- =============================================================================

-- Check trusted_partner_discounts table structure
SELECT '=== TRUSTED_PARTNER_DISCOUNTS TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;

-- Check businesses table structure
SELECT '=== BUSINESSES TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'businesses'
ORDER BY ordinal_position;

-- Check deal_authorizations table structure
SELECT '=== DEAL_AUTHORIZATIONS TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- Check notifications table structure
SELECT '=== NOTIFICATIONS TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;