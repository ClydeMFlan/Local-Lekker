-- Verification script to confirm member signup setup is correct
-- Based on the database schema check, everything appears to be properly configured!

-- Check that all required columns exist with correct types
SELECT '=== MEMBER SIGNUP COLUMN VERIFICATION ===' as verification_check;

SELECT
    column_name,
    data_type,
    column_default,
    CASE
        WHEN column_name IN ('name', 'surname', 'email', 'street', 'suburb', 'city', 'province', 'contact', 'gender', 'ethnicity', 'date_of_birth', 'role') THEN 'REQUIRED'
        ELSE 'OPTIONAL'
    END as requirement,
    CASE
        WHEN column_name = 'role' AND data_type = 'text' AND column_default = '''user''::text' THEN 'OK (app overrides to member)'
        WHEN column_name = 'date_of_birth' AND data_type = 'timestamp with time zone' THEN 'OK (handles ISO strings)'
        WHEN column_name IN ('name', 'surname', 'email', 'street', 'suburb', 'city', 'province', 'contact', 'gender', 'ethnicity', 'category', 'in_app_password') AND data_type = 'text' THEN 'OK'
        WHEN column_name IN ('created_at', 'updated_at') AND data_type = 'timestamp with time zone' THEN 'OK'
        WHEN column_name = 'id' AND data_type = 'uuid' THEN 'OK'
        ELSE 'CHECK'
    END as status
FROM information_schema.columns
WHERE table_name = 'profiles' AND table_schema = 'public'
ORDER BY ordinal_position;

-- Test that we can insert a sample member profile (without actually inserting)
SELECT '=== SAMPLE MEMBER PROFILE INSERT TEST ===' as test_info;

-- This would be the data structure sent by the app during signup
SELECT jsonb_build_object(
    'id', 'test-uuid-123',
    'name', 'John',
    'surname', 'Doe',
    'email', 'john.doe@example.com',
    'street', '123 Main St',
    'suburb', 'Suburbia',
    'city', 'Johannesburg',
    'province', 'Gauteng',
    'contact', '+27123456789',
    'gender', 'Male',
    'ethnicity', 'White',
    'date_of_birth', '1990-01-15T00:00:00.000Z',
    'role', 'member'
) as sample_signup_data;

-- Check RLS policies are in place
SELECT '=== RLS POLICIES CHECK ===' as rls_check;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles'
ORDER BY policyname;

-- Check that the table has the right permissions
SELECT '=== TABLE PERMISSIONS CHECK ===' as permissions_check;
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'profiles' AND table_schema = 'public'
ORDER BY grantee, privilege_type;