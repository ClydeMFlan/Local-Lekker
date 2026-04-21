-- SOLUTION: Clean up orphaned clydemfaln profile and memberships
-- Run this in Supabase SQL Editor to remove the orphaned records

-- First, get the profile details before deletion
SELECT 'PROFILE_TO_DELETE' as action, id, email, name, surname, role, subscription
FROM public.profiles
WHERE email ILIKE '%clydemfaln%';

-- Get membership details before deletion
SELECT 'MEMBERSHIP_TO_DELETE' as action, m.user_id, m.role, m.gateway, p.email
FROM public.memberships m
LEFT JOIN public.profiles p ON m.user_id = p.id
WHERE p.email ILIKE '%clydemfaln%';

-- Delete the orphaned membership record
DELETE FROM public.memberships
WHERE user_id IN (
    SELECT id FROM public.profiles
    WHERE email ILIKE '%clydemfaln%'
    AND id NOT IN (SELECT id FROM auth.users)
);

-- Delete the orphaned profile
DELETE FROM public.profiles
WHERE email ILIKE '%clydemfaln%'
AND id NOT IN (SELECT id FROM auth.users);

-- Verify cleanup
SELECT 'REMAINING_PROFILES' as check_type, COUNT(*) as count
FROM public.profiles
WHERE email ILIKE '%clydemfaln%';

SELECT 'REMAINING_MEMBERSHIPS' as check_type, COUNT(*) as count
FROM public.memberships
WHERE user_id NOT IN (SELECT id FROM auth.users);