-- Verify admin has correct role in memberships table for deal uploads

-- 1. Check if admin user exists in memberships with admin role
SELECT 
    user_id,
    role,
    created_at,
    '✅ Admin can upload deal images' as status
FROM memberships
WHERE role = 'admin';

-- 2. If no admin in memberships, check profiles table
SELECT 
    id as user_id,
    email,
    role,
    CASE 
        WHEN role = 'admin' THEN '⚠️ Admin in profiles but NOT in memberships - will fail RLS'
        ELSE 'Not admin'
    END as status
FROM profiles
WHERE role = 'admin'
  AND id NOT IN (SELECT user_id FROM memberships WHERE role = 'admin');

-- 3. Solution: Add admin to memberships if missing
-- Only run if query #2 returns results
/*
INSERT INTO memberships (user_id, role, created_at)
SELECT 
    id,
    'admin',
    NOW()
FROM profiles
WHERE role = 'admin'
  AND id NOT IN (SELECT user_id FROM memberships WHERE role = 'admin');
*/

-- 4. Verify That Old Oak allows admin deal creation
SELECT 
    name,
    owner_member_id,
    allow_admin_deal_creation,
    CASE 
        WHEN allow_admin_deal_creation = true THEN '✅ Admin CAN create deals'
        ELSE '❌ Admin CANNOT create deals - need to enable'
    END as admin_permission
FROM businesses
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';
