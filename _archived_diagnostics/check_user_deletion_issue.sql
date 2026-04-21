
-- Check if the user exists in trusted_partners table
SELECT 
    'User in trusted_partners:' as check_type,
    tp.user_id,
    tp.business_name,
    tp.created_at
FROM trusted_partners tp
WHERE tp.user_id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

-- Check if user exists in profiles
SELECT 
    'User in profiles:' as check_type,
    p.id,
    p.email,
    p.role,
    p.admin_created,
    p.password_set
FROM profiles p
WHERE p.id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

-- Check memberships table
SELECT 
    'User in memberships:' as check_type,
    m.user_id,
    m.role,
    m.created_at
FROM memberships m
WHERE m.user_id = '736ac25c-5e0b-45af-a3f0-c670c11aa222';

