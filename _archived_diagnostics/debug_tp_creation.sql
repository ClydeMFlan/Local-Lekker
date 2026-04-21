
-- Debug: Check what trusted partners actually exist
SELECT 
    'Trusted Partners Found:' as info,
    COUNT(*) as count
FROM trusted_partners;

-- Check recent trusted partners (last 24 hours)
SELECT 
    tp.user_id,
    tp.business_name,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set,
    tp.created_at
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
WHERE tp.created_at > NOW() - INTERVAL '24 hours'
ORDER BY tp.created_at DESC;

-- Check if there are any profiles with admin_created = true
SELECT 
    email,
    role,
    admin_created,
    password_set,
    created_at
FROM profiles 
WHERE admin_created = true
ORDER BY created_at DESC
LIMIT 5;

-- Check auth.users for recent signups
SELECT 
    email,
    raw_user_meta_data->>'user_type' as user_type,
    raw_user_meta_data->>'admin_created' as admin_created,
    created_at
FROM auth.users
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

