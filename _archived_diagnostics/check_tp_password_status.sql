
-- SQL Query to check admin-created trusted partners and password status

SELECT 
    'Admin-Created Trusted Partners:' as status_check,
    COUNT(*) as total_admin_created_tps
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
WHERE p.admin_created = true;

-- Detailed view of admin-created trusted partners
SELECT 
    p.id as user_id,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set,
    p.created_at as profile_created,
    p.updated_at as profile_updated,
    tp.business_name,
    tp.created_at as tp_created
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
WHERE p.admin_created = true
ORDER BY tp.created_at DESC;

-- Specifically check thecraftsmanel@gmail.com
SELECT 
    'Specific User Check - thecraftsmanel@gmail.com:' as user_check,
    p.id,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set,
    p.created_at,
    p.updated_at,
    CASE 
        WHEN p.password_set = true THEN 'PASSWORD IS SET - Should skip password creation'
        WHEN p.password_set = false THEN 'PASSWORD NOT SET - Should show password creation'
        ELSE 'NULL - Should show password creation'
    END as app_behavior_expected
FROM profiles p
LEFT JOIN trusted_partners tp ON tp.user_id = p.id
WHERE p.email = 'thecraftsmanel@gmail.com';

