-- Check businesses table structure
SELECT '=== BUSINESSES TABLE ===' as info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'businesses'
ORDER BY ordinal_position;