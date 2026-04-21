-- Debug query: Check what trusted partners actually exist
SELECT
    'Current trusted partners in database:' as info,
    COUNT(*) as total_count
FROM trusted_partners;

-- Show all trusted partners with their details
SELECT
    tp.created_at,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set,
    tp.business_name
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
ORDER BY tp.created_at DESC;

-- Check what emails exist in profiles that might be trusted partners
SELECT
    'All profiles with trusted_partner role:' as info,
    COUNT(*) as count
FROM profiles
WHERE role = 'trusted_partner';

-- Show recent profiles (last 24 hours)
SELECT
    created_at,
    email,
    name,
    surname,
    role,
    admin_created,
    password_set
FROM profiles
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- Check auth.users for any recent signups
SELECT
    'Recent auth.users (last 24h):' as info,
    COUNT(*) as count
FROM auth.users
WHERE created_at > NOW() - INTERVAL '24 hours';

-- Show recent auth users with metadata
SELECT
    created_at,
    email,
    raw_user_meta_data->>'user_type' as user_type,
    raw_user_meta_data->>'admin_created' as admin_created,
    raw_user_meta_data->>'password_set' as password_set
FROM auth.users
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;