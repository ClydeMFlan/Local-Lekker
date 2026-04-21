-- Find and delete user: houselillian5@gmail.com
-- Run this in Supabase SQL Editor

-- Step 1: Find the user ID
SELECT id, email, created_at
FROM auth.users
WHERE email = 'houselillian5@gmail.com';

-- Step 2: Check what data exists for this user (replace USER_ID with the actual ID from step 1)
-- SELECT 'profiles' as table_name, COUNT(*) as count FROM public.profiles WHERE id = 'USER_ID'
-- UNION ALL
-- SELECT 'memberships' as table_name, COUNT(*) as count FROM public.memberships WHERE user_id = 'USER_ID'
-- UNION ALL
-- SELECT 'merchants' as table_name, COUNT(*) as count FROM public.merchants WHERE user_id = 'USER_ID'
-- UNION ALL
-- SELECT 'businesses' as table_name, COUNT(*) as count FROM public.businesses WHERE owner_user_id = 'USER_ID';

-- Step 3: Delete user data in correct order (replace USER_ID with actual ID)
-- DELETE FROM public.businesses WHERE owner_user_id = 'USER_ID';
-- DELETE FROM public.merchants WHERE user_id = 'USER_ID';
-- DELETE FROM public.memberships WHERE user_id = 'USER_ID';
-- DELETE FROM public.profiles WHERE id = 'USER_ID';
-- DELETE FROM auth.users WHERE id = 'USER_ID';

-- Alternative: Complete cleanup script (replace USER_ID)
-- This script safely deletes a user and all associated data
DO $$
DECLARE
    target_user_id UUID := 'USER_ID'; -- Replace with actual user ID
BEGIN
    -- Delete in correct order to avoid foreign key violations
    DELETE FROM public.businesses WHERE owner_user_id = target_user_id;
    DELETE FROM public.merchants WHERE user_id = target_user_id;
    DELETE FROM public.memberships WHERE user_id = target_user_id;
    DELETE FROM public.profiles WHERE id = target_user_id;
    DELETE FROM auth.users WHERE id = target_user_id;

    RAISE NOTICE 'User % and all associated data deleted successfully', target_user_id;
END $$;