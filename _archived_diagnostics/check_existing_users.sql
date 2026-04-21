-- Check what users exist in profiles table
SELECT '=== EXISTING PROFILES ===' as info;
SELECT id, email, role, created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 10;

-- Also check auth.users to see all users
SELECT '=== EXISTING AUTH USERS ===' as info;
SELECT id, email, created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 10;