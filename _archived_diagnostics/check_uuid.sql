-- Check what the UUID 78e67dc8-583b-4fe0-84e6-aa4d0c55a92e represents
SELECT
    'auth.users' as table_name,
    id,
    email,
    created_at
FROM auth.users
WHERE id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'

UNION ALL

SELECT
    'trusted_partners' as table_name,
    user_id as id,
    business_name as email,
    created_at
FROM trusted_partners
WHERE id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'
   OR user_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'

UNION ALL

SELECT
    'profiles' as table_name,
    id,
    email,
    created_at
FROM profiles
WHERE id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'

UNION ALL

SELECT
    'businesses' as table_name,
    owner_member_id as id,
    business_name as email,
    created_at
FROM businesses
WHERE owner_member_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';