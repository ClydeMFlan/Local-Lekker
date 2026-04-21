-- Verify that the trusted partner payment flow migration was applied successfully

-- Check processed_bills table has new columns
SELECT
    'processed_bills columns' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'processed_bills'
    AND column_name IN ('approval_status', 'approved_at', 'approved_by', 'rejection_reason', 'payment_method', 'payment_id')
ORDER BY column_name;

-- Check trusted_partner_bank_accounts table exists and has correct structure
SELECT
    'trusted_partner_bank_accounts table' as check_type,
    COUNT(*) as table_exists
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'trusted_partner_bank_accounts';

-- Check trusted_partner_bank_accounts columns
SELECT
    'trusted_partner_bank_accounts columns' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'trusted_partner_bank_accounts'
ORDER BY ordinal_position;

-- Check bill_approvals table exists and has correct structure
SELECT
    'bill_approvals table' as check_type,
    COUNT(*) as table_exists
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'bill_approvals';

-- Check bill_approvals columns
SELECT
    'bill_approvals columns' as check_type,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'bill_approvals'
ORDER BY ordinal_position;

-- Check RLS is enabled on new tables
SELECT
    'RLS enabled check' as check_type,
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
    AND tablename IN ('trusted_partner_bank_accounts', 'bill_approvals');

-- Check policies exist
SELECT
    'RLS policies' as check_type,
    schemaname,
    tablename,
    policyname
FROM pg_policies
WHERE schemaname = 'public'
    AND tablename IN ('trusted_partner_bank_accounts', 'bill_approvals')
ORDER BY tablename, policyname;

-- Check triggers exist
SELECT
    'Triggers check' as check_type,
    event_object_schema,
    event_object_table,
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
    AND event_object_table IN ('processed_bills', 'bill_approvals', 'trusted_partner_bank_accounts')
ORDER BY event_object_table, trigger_name;

-- Check functions exist
SELECT
    'Functions check' as check_type,
    routine_schema,
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
    AND routine_name IN (
        'create_bill_approval',
        'update_bill_approval_status',
        'update_trusted_partner_bank_accounts_updated_at',
        'update_bill_approvals_updated_at'
    )
ORDER BY routine_name;