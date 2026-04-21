
-- Quick test: Create a trusted partner directly via SQL to verify trigger works
-- This bypasses the Flutter app to test if the database trigger works

DO \$\$
DECLARE
    test_email TEXT := 'trigger_test_' || extract(epoch from now())::text || '@example.com';
    test_user_id UUID;
BEGIN
    -- Create user in auth.users (simulating what Supabase Auth does)
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        invited_at,
        confirmation_token,
        confirmation_sent_at,
        recovery_token,
        recovery_sent_at,
        email_change_token_new,
        email_change,
        email_change_sent_at,
        last_sign_in_at,
        app_metadata,
        user_metadata,
        is_super_admin,
        created_at,
        updated_at,
        phone,
        phone_confirmed_at,
        phone_change,
        phone_change_token,
        phone_change_sent_at,
        email_change_token_current,
        email_change_confirm_status,
        banned_until,
        reauthentication_token,
        reauthentication_sent_at,
        is_sso_user,
        deleted_at,
        is_anonymous,
        raw_app_meta_data,
        raw_user_meta_data
    ) VALUES (
        '00000000-0000-0000-0000-000000000000'::uuid,
        gen_random_uuid(),
        'authenticated',
        'authenticated',
        test_email,
        '\\\',
        now(),
        NULL,
        '',
        NULL,
        '',
        NULL,
        '',
        '',
        NULL,
        NULL,
        '{}'::jsonb,
        '{}'::jsonb,
        false,
        now(),
        now(),
        NULL,
        NULL,
        '',
        '',
        NULL,
        '',
        0,
        NULL,
        '',
        NULL,
        false,
        NULL,
        false,
        '{}'::jsonb,
        jsonb_build_object(
            'user_type', 'trusted_partner',
            'admin_created', 'true',
            'password_set', 'false',
            'email_verified', 'false',
            'name', 'Trigger Test',
            'surname', 'User',
            'business_name', 'Trigger Test Business'
        )
    ) RETURNING id INTO test_user_id;
    
    RAISE NOTICE 'Created test user with ID: % and email: %', test_user_id, test_email;
END
\$\$;

-- Check if the trigger created the records
SELECT 
    'Trigger Test Results:' as info,
    au.email,
    au.raw_user_meta_data->>'user_type' as user_type,
    p.role,
    p.admin_created,
    p.password_set,
    m.role as membership_role,
    tp.business_name
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
LEFT JOIN memberships m ON au.id = m.user_id
LEFT JOIN trusted_partners tp ON au.id = tp.user_id
WHERE au.email LIKE 'trigger_test_%@example.com'
ORDER BY au.created_at DESC
LIMIT 1;

