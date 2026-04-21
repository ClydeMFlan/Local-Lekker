-- Check ONLY trusted_partner_discounts table structure
SELECT '=== TRUSTED_PARTNER_DISCOUNTS TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;