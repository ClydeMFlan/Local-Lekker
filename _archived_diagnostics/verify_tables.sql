-- SQL to verify all deal authorization tables are created

-- Check if all tables exist
SELECT
    schemaname,
    tablename,
    tableowner
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'deal_authorizations',
        'virtual_receipts',
        'member_receipts',
        'notifications'
    )
ORDER BY tablename;

-- Check if in_app_password column was added to profiles table
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
    AND column_name = 'in_app_password';

-- Show structure of deal_authorizations table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- Show structure of virtual_receipts table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'virtual_receipts'
ORDER BY ordinal_position;

-- Show structure of member_receipts table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'member_receipts'
ORDER BY ordinal_position;

-- Show structure of notifications table
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- Check if indexes were created
SELECT
    indexname,
    tablename,
    indexdef
FROM pg_indexes
WHERE tablename IN (
    'deal_authorizations',
    'virtual_receipts',
    'member_receipts',
    'notifications'
)
ORDER BY tablename, indexname;

-- Check if RLS is enabled on all tables
SELECT
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN (
        'deal_authorizations',
        'virtual_receipts',
        'member_receipts',
        'notifications'
    )
ORDER BY tablename;

-- Count existing policies (should show policies for each table)
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename IN (
        'deal_authorizations',
        'virtual_receipts',
        'member_receipts',
        'notifications'
    )
ORDER BY tablename, policyname;
