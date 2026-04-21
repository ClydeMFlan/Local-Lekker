-- Verify the relationship between auth.users and profiles for houselillian5@gmail.com
SELECT 
    'auth.users' as table_name,
    id,
    email
FROM auth.users 
WHERE email = 'houselillian5@gmail.com'

UNION ALL

SELECT 
    'profiles' as table_name,
    id,
    email
FROM profiles 
WHERE email = 'houselillian5@gmail.com';

-- Check what owner_member_id refers to
SELECT 
    'businesses.owner_member_id' as label,
    '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e' as id;
