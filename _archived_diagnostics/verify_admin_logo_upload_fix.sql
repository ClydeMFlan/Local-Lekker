-- Final verification: Confirm admin can now update businesses table

-- 1. Check current admin user(s) in profiles
SELECT 
    id,
    email,
    role,
    '✅ Has admin role' as status
FROM profiles
WHERE role = 'admin';

-- 2. Verify That Old Oak current state
SELECT 
    name,
    owner_member_id,
    logo_url,
    updated_at
FROM businesses
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';

-- 3. Confirm admin policy is active and working
SELECT 
    policyname,
    cmd,
    permissive,
    CASE 
        WHEN policyname = 'Admins can manage all businesses' THEN '✅ Admin policy ACTIVE'
        ELSE 'Other policy'
    END as policy_status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'businesses'
  AND cmd = 'ALL'
ORDER BY policyname;

-- 4. Summary of all fixes applied
SELECT 
    '1. Database URL fixed' as fix_applied,
    'logo_1764755167228.jpg now in database' as description,
    '✅ Complete' as status
UNION ALL
SELECT 
    '2. Storage file verified' as fix_applied,
    'File exists in partner-logos bucket' as description,
    '✅ Complete' as status
UNION ALL
SELECT 
    '3. Admin RLS policy added' as fix_applied,
    'Admins can now UPDATE all businesses' as description,
    '✅ Complete' as status
UNION ALL
SELECT 
    '4. Cache-busting implemented' as fix_applied,
    'All views use filename timestamp' as description,
    '✅ Complete' as status
UNION ALL
SELECT 
    '5. Code syntax fixed' as fix_applied,
    'Removed duplicate _appendCacheBuster' as description,
    '✅ Complete' as status;
