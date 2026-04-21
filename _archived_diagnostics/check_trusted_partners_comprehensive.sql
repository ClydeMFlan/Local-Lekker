-- Check trusted_partners table structure and contents
-- This script provides comprehensive information about the trusted_partners table

-- 1. Check table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default,
    col_description.description
FROM information_schema.columns
LEFT JOIN pg_description col_description ON
    col_description.objoid = (SELECT oid FROM pg_class WHERE relname = 'trusted_partners') AND
    col_description.objsubid = information_schema.columns.ordinal_position
WHERE table_name = 'trusted_partners'
ORDER BY ordinal_position;

-- 2. Check table indexes
SELECT
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'trusted_partners';

-- 3. Check Row Level Security (RLS) policies
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
WHERE tablename = 'trusted_partners';

-- 4. Check foreign key constraints
SELECT
    tc.table_schema,
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_schema AS foreign_table_schema,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM
    information_schema.table_constraints AS tc
    JOIN information_schema.key_column_usage AS kcu
      ON tc.constraint_name = kcu.constraint_name
      AND tc.table_schema = kcu.table_schema
    JOIN information_schema.constraint_column_usage AS ccu
      ON ccu.constraint_name = tc.constraint_name
      AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_name = 'trusted_partners';

-- 5. Check current table contents (all records) - using actual column names
SELECT *
FROM trusted_partners
ORDER BY created_at DESC;

-- 6. Check record count - only count columns that exist
SELECT
    COUNT(*) as total_records,
    COUNT(paystack_recipient_code) as records_with_recipient_code,
    COUNT(paystack_subaccount_id) as records_with_subaccount_id
FROM trusted_partners;

-- 7. Check for any orphaned records (user_id not in profiles)
SELECT tp.*
FROM trusted_partners tp
LEFT JOIN profiles p ON tp.user_id = p.id
WHERE p.id IS NULL;

-- 8. Check for duplicate user_ids
SELECT user_id, COUNT(*) as duplicate_count
FROM trusted_partners
GROUP BY user_id
HAVING COUNT(*) > 1;

-- 9. Check recent updates (last 30 days)
SELECT *
FROM trusted_partners
WHERE updated_at >= NOW() - INTERVAL '30 days'
ORDER BY updated_at DESC;

-- 10. Check if paystack_recipient_code follows expected format (RCP_...)
SELECT
    paystack_recipient_code,
    CASE
        WHEN paystack_recipient_code LIKE 'RCP_%' THEN 'Valid Format'
        WHEN paystack_recipient_code IS NULL THEN 'NULL'
        ELSE 'Invalid Format'
    END as format_check
FROM trusted_partners
WHERE paystack_recipient_code IS NOT NULL;