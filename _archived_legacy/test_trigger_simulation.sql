-- Test script: Simulate admin creating a trusted partner
-- This directly tests the database trigger and record creation

-- Step 1: Check current state before test
SELECT 'BEFORE TEST - Trusted partners count:' as status, COUNT(*) as count FROM trusted_partners;
SELECT 'BEFORE TEST - Profiles count:' as status, COUNT(*) as count FROM profiles;
SELECT 'BEFORE TEST - Auth users count:' as status, COUNT(*) as count FROM auth.users;

-- Step 2: Simulate what happens when admin creates trusted partner
-- Insert a test user directly into auth.users with the metadata that would be set by signUpWithOtp
-- This should trigger our handle_new_user_role_assignment_trigger function

-- Generate a unique test email
DO $$
DECLARE
    test_email TEXT := 'test_trigger_' || EXTRACT(epoch FROM NOW())::TEXT || '@example.com';
    test_user_id UUID := gen_random_uuid();
BEGIN
    RAISE NOTICE 'Creating test trusted partner with email: %', test_email;

    -- Insert into auth.users (this should trigger our function)
    INSERT INTO auth.users (
        id,
        email,
        encrypted_password,
        email_confirmed_at,
        created_at,
        updated_at,
        raw_user_meta_data,
        aud,
        role
    ) VALUES (
        test_user_id,
        test_email,
        crypt('testpassword123', gen_salt('bf')),
        NOW(),
        NOW(),
        NOW(),
        jsonb_build_object(
            'user_type', 'trusted_partner',
            'admin_created', 'true',
            'password_set', 'false',
            'email_verified', 'false',
            'name', 'Test Trigger',
            'surname', 'Partner',
            'email', test_email,
            'business_name', 'Test Trigger Business'
        ),
        'authenticated',
        'authenticated'
    );

    RAISE NOTICE 'Test user created with ID: %', test_user_id;
END $$;

-- Step 3: Wait a moment for trigger to execute
SELECT pg_sleep(2);

-- Step 4: Check results after test
SELECT 'AFTER TEST - Trusted partners count:' as status, COUNT(*) as count FROM trusted_partners;
SELECT 'AFTER TEST - Profiles count:' as status, COUNT(*) as count FROM profiles;

-- Step 5: Show the created records
SELECT
    'Created Profile:' as record_type,
    p.id,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set
FROM profiles p
WHERE p.email LIKE 'test_trigger_%@example.com'
ORDER BY p.created_at DESC
LIMIT 1;

SELECT
    'Created Membership:' as record_type,
    m.user_id,
    m.role,
    m.gateway
FROM memberships m
JOIN profiles p ON m.user_id = p.id
WHERE p.email LIKE 'test_trigger_%@example.com'
ORDER BY m.created_at DESC
LIMIT 1;

SELECT
    'Created Trusted Partner:' as record_type,
    tp.user_id,
    tp.business_name,
    tp.created_at
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
WHERE p.email LIKE 'test_trigger_%@example.com'
ORDER BY tp.created_at DESC
LIMIT 1;

-- Step 6: Run the verification checks on our test data
SELECT
    check_id,
    CASE
        WHEN check_id = 1 THEN 'User exists in auth.users'
        WHEN check_id = 2 THEN 'Profile record exists with correct flags'
        WHEN check_id = 3 THEN 'Membership record exists'
        WHEN check_id = 4 THEN 'Trusted partner record exists'
    END as check_description,
    CASE WHEN check_result THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM (
    -- Check 1: User exists in auth.users
    SELECT 1 as check_id,
           EXISTS (
               SELECT 1 FROM auth.users
               WHERE email LIKE 'test_trigger_%@example.com'
               AND raw_user_meta_data->>'user_type' = 'trusted_partner'
           ) as check_result

    UNION ALL

    -- Check 2: Profile record exists with correct flags
    SELECT 2 as check_id,
           EXISTS (
               SELECT 1 FROM profiles
               WHERE email LIKE 'test_trigger_%@example.com'
               AND role = 'trusted_partner'
               AND admin_created = true
               AND password_set = false
           ) as check_result

    UNION ALL

    -- Check 3: Membership record exists
    SELECT 3 as check_id,
           EXISTS (
               SELECT 1 FROM memberships m
               JOIN profiles p ON m.user_id = p.id
               WHERE p.email LIKE 'test_trigger_%@example.com'
               AND m.role = 'trusted_partner'
           ) as check_result

    UNION ALL

    -- Check 4: Trusted partner record exists
    SELECT 4 as check_id,
           EXISTS (
               SELECT 1 FROM trusted_partners tp
               JOIN profiles p ON tp.user_id = p.id
               WHERE p.email LIKE 'test_trigger_%@example.com'
               AND tp.business_name IS NOT NULL
           ) as check_result
) checks
ORDER BY check_id;

-- Summary
SELECT
    COUNT(*) as total_checks,
    SUM(CASE WHEN check_result THEN 1 ELSE 0 END) as passed_checks,
    CASE
        WHEN COUNT(*) = SUM(CASE WHEN check_result THEN 1 ELSE 0 END) THEN '✅ ALL CHECKS PASSED - TRIGGER WORKS!'
        ELSE '❌ SOME CHECKS FAILED - TRIGGER BROKEN'
    END as overall_status
FROM (
    -- Check 1: User exists in auth.users
    SELECT EXISTS (
        SELECT 1 FROM auth.users
        WHERE email LIKE 'test_trigger_%@example.com'
        AND raw_user_meta_data->>'user_type' = 'trusted_partner'
    ) as check_result

    UNION ALL

    -- Check 2: Profile record exists with correct flags
    SELECT EXISTS (
        SELECT 1 FROM profiles
        WHERE email LIKE 'test_trigger_%@example.com'
        AND role = 'trusted_partner'
        AND admin_created = true
        AND password_set = false
    ) as check_result

    UNION ALL

    -- Check 3: Membership record exists
    SELECT EXISTS (
        SELECT 1 FROM memberships m
        JOIN profiles p ON m.user_id = p.id
        WHERE p.email LIKE 'test_trigger_%@example.com'
        AND m.role = 'trusted_partner'
    ) as check_result

    UNION ALL

    -- Check 4: Trusted partner record exists
    SELECT EXISTS (
        SELECT 1 FROM trusted_partners tp
        JOIN profiles p ON tp.user_id = p.id
        WHERE p.email LIKE 'test_trigger_%@example.com'
        AND tp.business_name IS NOT NULL
    ) as check_result
) checks;