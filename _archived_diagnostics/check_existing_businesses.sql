-- Check what businesses already exist
SELECT '=== EXISTING BUSINESSES ===' as info;
SELECT id, owner_member_id, name, verified
FROM businesses
ORDER BY created_at DESC;

-- Check which trusted partners already have businesses
SELECT '=== TRUSTED PARTNERS WITH BUSINESSES ===' as info;
SELECT 
    p.email,
    p.id as profile_id,
    b.id as business_id,
    b.name as business_name
FROM profiles p
LEFT JOIN businesses b ON p.id = b.owner_member_id
WHERE p.role = 'trusted_partner'
ORDER BY p.created_at DESC;