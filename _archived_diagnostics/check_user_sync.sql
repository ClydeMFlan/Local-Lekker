-- =====================================================
-- CHECK USER SYNC BETWEEN AUTH AND PROFILES
-- Diagnose missing members and trusted partners
-- =====================================================

-- 1. Count users in auth.users
SELECT 
  'auth.users' as table_name,
  COUNT(*) as total_count
FROM auth.users;

-- 2. Count users in profiles
SELECT 
  'profiles' as table_name,
  COUNT(*) as total_count
FROM profiles;

-- 3. Count by role in profiles
SELECT 
  role,
  COUNT(*) as count,
  SUM(CASE WHEN verified = true THEN 1 ELSE 0 END) as verified_count,
  SUM(CASE WHEN verified = false OR verified IS NULL THEN 1 ELSE 0 END) as pending_count
FROM profiles
GROUP BY role
ORDER BY role;

-- 4. Users in auth.users but NOT in profiles (orphaned auth accounts)
SELECT 
  au.id,
  au.email,
  au.created_at,
  'Missing from profiles' as issue
FROM auth.users au
LEFT JOIN profiles p ON au.id = p.id
WHERE p.id IS NULL
ORDER BY au.created_at DESC;

-- 5. Users in profiles but NOT in auth.users (orphaned profiles)
SELECT 
  p.id,
  p.email,
  p.name,
  p.surname,
  p.role,
  'Missing from auth.users' as issue
FROM profiles p
LEFT JOIN auth.users au ON p.id = au.id
WHERE au.id IS NULL
ORDER BY p.created_at DESC;

-- 6. Check memberships table
SELECT 
  role,
  COUNT(*) as count
FROM memberships
GROUP BY role
ORDER BY role;

-- 7. Members with memberships but no profile
SELECT 
  m.user_id,
  m.role,
  'Has membership but no profile' as issue
FROM memberships m
LEFT JOIN profiles p ON m.user_id = p.id
WHERE m.role = 'member' AND p.id IS NULL;

-- 8. Trusted partners with memberships but no profile
SELECT 
  m.user_id,
  m.role,
  'Has membership but no profile' as issue
FROM memberships m
LEFT JOIN profiles p ON m.user_id = p.id
WHERE m.role = 'trusted_partner' AND p.id IS NULL;

-- 9. Full member details
SELECT 
  p.id,
  p.email,
  p.name,
  p.surname,
  p.role,
  p.verified,
  p.created_at,
  CASE WHEN m.user_id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_membership,
  CASE WHEN au.id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_auth
FROM profiles p
LEFT JOIN memberships m ON p.id = m.user_id AND m.role = 'member'
LEFT JOIN auth.users au ON p.id = au.id
WHERE p.role = 'member'
ORDER BY p.created_at DESC;

-- 10. Full trusted partner details
SELECT 
  p.id,
  p.email,
  p.name,
  p.surname,
  p.role,
  p.verified,
  p.created_at,
  CASE WHEN m.user_id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_membership,
  CASE WHEN au.id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_auth,
  CASE WHEN tp.user_id IS NOT NULL THEN 'Yes' ELSE 'No' END as has_tp_record
FROM profiles p
LEFT JOIN memberships m ON p.id = m.user_id AND m.role = 'trusted_partner'
LEFT JOIN auth.users au ON p.id = au.id
LEFT JOIN trusted_partners tp ON p.id = tp.user_id
WHERE p.role = 'trusted_partner'
ORDER BY p.created_at DESC;

-- 11. Check for email mismatches
SELECT 
  au.id,
  au.email as auth_email,
  p.email as profile_email,
  'Email mismatch' as issue
FROM auth.users au
INNER JOIN profiles p ON au.id = p.id
WHERE au.email != p.email;

-- 12. Summary report
SELECT 
  'Total auth.users' as metric,
  COUNT(*)::text as value
FROM auth.users
UNION ALL
SELECT 
  'Total profiles',
  COUNT(*)::text
FROM profiles
UNION ALL
SELECT 
  'Total memberships',
  COUNT(*)::text
FROM memberships
UNION ALL
SELECT 
  'Members in profiles',
  COUNT(*)::text
FROM profiles WHERE role = 'member'
UNION ALL
SELECT 
  'TPs in profiles',
  COUNT(*)::text
FROM profiles WHERE role = 'trusted_partner'
UNION ALL
SELECT 
  'Verified members',
  COUNT(*)::text
FROM profiles WHERE role = 'member' AND verified = true
UNION ALL
SELECT 
  'Pending members',
  COUNT(*)::text
FROM profiles WHERE role = 'member' AND (verified = false OR verified IS NULL)
UNION ALL
SELECT 
  'Verified TPs',
  COUNT(*)::text
FROM profiles WHERE role = 'trusted_partner' AND verified = true
UNION ALL
SELECT 
  'Pending TPs',
  COUNT(*)::text
FROM profiles WHERE role = 'trusted_partner' AND (verified = false OR verified IS NULL);
