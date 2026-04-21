-- Quick check for the specific user ID that was failing
-- Run this in Supabase SQL Editor

-- Check if this user ID exists anywhere
SELECT 'Checking user 736ac25c-5e0b-45af-a3f0-c670c11aa222:' as check;

SELECT 'profiles' as table_name, COUNT(*) as count
FROM profiles WHERE id = '736ac25c-5e0b-45af-a3f0-c670c11aa222'
UNION ALL
SELECT 'trusted_partners' as table_name, COUNT(*) as count
FROM trusted_partners WHERE user_id = '736ac25c-5e0b-45af-a3f0-c670c11aa222'
UNION ALL
SELECT 'auth.users' as table_name, COUNT(*) as count
FROM auth.users WHERE id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

-- Show all trusted partners currently in the system
SELECT 'All current trusted partners:' as info;

SELECT
    p.id,
    p.email,
    p.name,
    p.role,
    p.admin_created,
    tp.business_name
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
ORDER BY tp.created_at DESC;

-- Check for orphaned profiles (trusted_partner role but no trusted_partners record)
SELECT 'Orphaned trusted partner profiles:' as orphaned;

SELECT
    p.id,
    p.email,
    p.name,
    p.role,
    p.admin_created,
    p.password_set
FROM profiles p
LEFT JOIN trusted_partners tp ON tp.user_id = p.id
WHERE p.role = 'trusted_partner' AND tp.user_id IS NULL;
