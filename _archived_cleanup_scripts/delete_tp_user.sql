-- =====================================================
-- DELETE TRUSTED PARTNER AND ASSOCIATED USER
-- UUID: 78e67dc8-583b-4fe0-84e6-aa4d0c55a92e
-- =====================================================

-- First, check what this UUID represents
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
WHERE user_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'

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

-- ALTERNATIVE: Check each table individually (if UNION fails)
-- Check auth.users
SELECT 'auth.users' as source, id, email, created_at
FROM auth.users
WHERE id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';

-- Check profiles
SELECT 'profiles' as source, id, email, created_at
FROM profiles
WHERE id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';

-- Check trusted_partners (by user_id)
SELECT 'trusted_partners' as source, user_id, business_name, created_at
FROM trusted_partners
WHERE user_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';

-- Check businesses
SELECT 'businesses' as source, owner_member_id, business_name, created_at
FROM businesses
WHERE owner_member_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';

-- After identifying the user ID, run the deletion:
-- SELECT admin_delete_user('THE-ACTUAL-USER-ID-HERE');

-- Example:
-- SELECT admin_delete_user('78e67dc8-583b-4fe0-84e6-aa4d0c55a92e');

-- After identifying the user ID, run the deletion:
-- SELECT admin_delete_user('THE-ACTUAL-USER-ID-HERE');

-- Example:
-- SELECT admin_delete_user('78e67dc8-583b-4fe0-84e6-aa4d0c55a92e');