-- Test the Edge Function directly
-- This will help us see if the JWT/service role key issue is blocking the function

-- First, let's check what the current admin user looks like
SELECT
    'Admin User Check:' as status,
    au.id,
    au.email,
    au.created_at,
    CASE WHEN au.email = 'admin@locallekker.com' THEN 'IS_ADMIN' ELSE 'NOT_ADMIN' END as admin_status
FROM auth.users au
WHERE au.email = 'admin@locallekker.com';

-- Check if the admin has a profile
SELECT
    'Admin Profile Check:' as status,
    p.id,
    p.email,
    p.role,
    p.created_at
FROM profiles p
WHERE p.email = 'admin@locallekker.com';

-- Test the database function directly (without Edge Function)
-- This should work and delete the data, leaving only auth user deletion
-- SELECT admin_delete_trusted_partner_data('YOUR_TP_USER_ID_HERE'::uuid);