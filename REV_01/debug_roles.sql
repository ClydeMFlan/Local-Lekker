-- Check current database state for role assignment
-- This will help us understand why roles are still being assigned as 'member'

-- 1. Check the most recent users and their metadata
SELECT
  u.id,
  u.email,
  u.created_at,
  u.raw_app_meta_data->>'user_type' as user_type,
  u.raw_user_meta_data as user_metadata
FROM auth.users u
ORDER BY u.created_at DESC
LIMIT 10;

-- 2. Check profiles table for role assignments
SELECT
  p.id,
  p.email,
  p.role,
  p.created_at,
  p.updated_at
FROM public.profiles p
ORDER BY p.created_at DESC
LIMIT 10;

-- 3. Check memberships table for role assignments
SELECT
  m.user_id,
  m.role,
  m.gateway,
  m.created_at,
  m.updated_at
FROM public.memberships m
ORDER BY m.created_at DESC
LIMIT 10;

-- 4. Check if merchants table has records
SELECT
  mer.user_id,
  mer.business_name,
  mer.created_at
FROM public.merchants mer
ORDER BY mer.created_at DESC
LIMIT 10;

-- 5. Combined view of recent users with all their data
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data->>'user_type' as signup_type,
  p.role as profile_role,
  m.role as membership_role,
  mer.business_name,
  u.created_at as user_created,
  p.created_at as profile_created,
  m.created_at as membership_created
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.memberships m ON u.id = m.user_id
LEFT JOIN public.merchants mer ON u.id = mer.user_id
ORDER BY u.created_at DESC
LIMIT 10;