-- Check what profiles actually exist
SELECT '=== ALL EXISTING PROFILES ===' as info;
SELECT id, email, role, created_at
FROM profiles
ORDER BY created_at DESC;

-- Find profiles with different roles for testing
SELECT '=== PROFILE COUNT BY ROLE ===' as info;
SELECT role, COUNT(*) as count
FROM profiles
GROUP BY role;

-- Check if we have both member and trusted_partner roles
SELECT '=== ROLE AVAILABILITY CHECK ===' as info;
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM profiles WHERE role = 'member') THEN 'YES'
        ELSE 'NO'
    END as has_members,
    CASE
        WHEN EXISTS (SELECT 1 FROM profiles WHERE role = 'trusted_partner') THEN 'YES'
        ELSE 'NO'
    END as has_trusted_partners;

-- Show all profiles with their details
SELECT '=== DETAILED PROFILE LIST ===' as info;
SELECT
    ROW_NUMBER() OVER (ORDER BY created_at DESC) as profile_number,
    id,
    email,
    role,
    created_at
FROM profiles
ORDER BY created_at DESC;