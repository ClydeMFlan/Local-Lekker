-- Test the delete-auth-user Edge Function (UPDATED)
-- Run this in Supabase SQL Editor to check admin permissions

-- 1. Check if the current user is an admin (by email)
-- The Edge Function now checks if email = 'admin@locallekker.com'
SELECT 'Current admin status:' as check,
       auth.email() as current_user_email,
       CASE WHEN auth.email() = 'admin@locallekker.com' THEN 'IS_ADMIN' ELSE 'NOT_ADMIN' END as admin_status;

-- 2. Check what the current user's email is
SELECT 'Current user details:' as check,
       auth.uid() as user_id,
       auth.email() as user_email;

-- 3. If you need to test as admin, make sure you're logged in with admin@locallekker.com
-- The Edge Function will reject requests from non-admin emails

-- 4. Test the Edge Function call (replace YOUR_TOKEN with actual admin access token):
-- curl -X POST 'https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/delete-auth-user' \
--   -H 'Content-Type: application/json' \
--   -H 'Authorization: Bearer YOUR_ADMIN_TOKEN' \
--   -d '{"user_id":"736ac25c-5e0b-45af-a3f0-c670c11aa222"}'