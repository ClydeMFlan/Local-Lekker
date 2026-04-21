-- Check current user role and available trusted partners for testing
SELECT
    'Current User Role Check:' as info,
    p.id,
    p.email,
    p.role,
    p.name,
    p.surname,
    CASE WHEN p.email = 'admin@locallekker.com' THEN '✅ IS ADMIN' ELSE '❌ NOT ADMIN' END as admin_status
FROM profiles p
WHERE p.id = '985fa2aa-45c7-450a-a8b8-ff63934a6193';

-- Check if there are any trusted partners to test deletion with
SELECT
    'Available Trusted Partners for Testing:' as info,
    COUNT(*) as total_tp,
    STRING_AGG(tp.business_name, ', ') as business_names
FROM trusted_partners tp;

-- Get details of trusted partners for testing
SELECT
    'Trusted Partner Details:' as info,
    tp.user_id,
    p.email,
    p.name,
    p.surname,
    tp.business_name,
    tp.created_at
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
ORDER BY tp.created_at DESC
LIMIT 5;