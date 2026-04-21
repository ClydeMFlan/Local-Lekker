-- Debug auth user deletion issue
-- Run this in Supabase SQL Editor

-- 1. Check if the user still exists after attempted deletion
SELECT 'Check if user still exists:' as debug;
SELECT
    'auth.users' as table_name,
    COUNT(*) as record_count
FROM auth.users
WHERE email = 'thecraftsmanel@gmail.com'

UNION ALL

SELECT
    'profiles' as table_name,
    COUNT(*) as record_count
FROM profiles
WHERE email = 'thecraftsmanel@gmail.com';

-- 2. Check admin permissions
SELECT 'Admin permissions check:' as debug;
SELECT
    auth.uid() as current_user_id,
    CASE WHEN EXISTS (
        SELECT 1 FROM admin_dashboard WHERE admin_user_id = auth.uid()
    ) THEN 'HAS_ADMIN_ACCESS' ELSE 'NO_ADMIN_ACCESS' END as admin_status;

-- 3. Test Edge Function manually (if you have curl or can test via API)
-- The Edge Function URL is: https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/delete-auth-user
-- Method: POST
-- Headers: Content-Type: application/json, Authorization: Bearer <admin_token>
-- Body: {"user_id": "736ac25c-5e0b-45af-a3f0-c670c11aa222"}

-- 4. If Edge Function fails, check these common issues:
-- a) Admin user not in admin_dashboard table
-- b) Service role key not set in Edge Function secrets
-- c) Edge Function not deployed (but we confirmed it is)

-- 5. Manual cleanup if needed (run with caution):
-- DELETE FROM auth.users WHERE id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';
-- (Requires direct database access, not available in hosted Supabase)