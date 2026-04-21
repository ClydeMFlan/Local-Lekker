-- Quick verification script for automatic role assignment
-- Run this in Supabase SQL Editor to check if the trigger worked

-- Check the most recent user and their role assignments
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data->>'user_type' as user_type,
  p.role as profile_role,
  m.role as membership_role,
  u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.memberships m ON u.id = m.user_id
WHERE u.created_at > NOW() - INTERVAL '1 hour'  -- Last hour
ORDER BY u.created_at DESC
LIMIT 5;

-- Check if merchants table was populated for merchant users
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data->>'user_type' as user_type,
  mer.business_name,
  u.created_at
FROM auth.users u
LEFT JOIN public.merchants mer ON u.id = mer.user_id
WHERE u.raw_app_meta_data->>'user_type' = 'merchant'
  AND u.created_at > NOW() - INTERVAL '1 hour'
ORDER BY u.created_at DESC;