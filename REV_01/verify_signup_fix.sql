-- Verification script - run after applying complete_signup_fix.sql
-- This confirms all signup-critical components are working

-- Check tables exist
SELECT '=== TABLES VERIFICATION ===' as check_type;
SELECT
    'profiles' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
UNION ALL
SELECT
    'users' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
UNION ALL
SELECT
    'memberships' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'memberships') THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- Check RLS is enabled
SELECT '=== RLS STATUS VERIFICATION ===' as check_type;
SELECT
    t.tablename,
    CASE WHEN c.relrowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND t.tablename IN ('profiles', 'users', 'memberships')
ORDER BY t.tablename;

-- Check INSERT policies exist
SELECT '=== INSERT POLICIES VERIFICATION ===' as check_type;
SELECT
    tablename,
    policyname,
    CASE WHEN policyname IS NOT NULL THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
FROM (
    SELECT 'profiles' as tablename, 'Users can insert own profile' as expected_policy
    UNION ALL
    SELECT 'users' as tablename, 'Users can insert own user record' as expected_policy
    UNION ALL
    SELECT 'memberships' as tablename, 'Users can insert memberships' as expected_policy
) expected
LEFT JOIN pg_policies p ON p.tablename = expected.tablename
    AND p.policyname = expected.expected_policy
    AND p.cmd = 'INSERT'
ORDER BY tablename;

-- Summary
SELECT '=== SIGNUP READINESS SUMMARY ===' as summary;
SELECT
    CASE
        WHEN (
            -- All tables exist
            (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('profiles', 'users', 'memberships')) = 3
            AND
            -- All have RLS enabled
            (SELECT COUNT(*) FROM pg_tables t LEFT JOIN pg_class c ON c.relname = t.tablename
             WHERE t.schemaname = 'public' AND t.tablename IN ('profiles', 'users', 'memberships')
             AND c.relrowsecurity = true) = 3
            AND
            -- All have INSERT policies
            (SELECT COUNT(*) FROM pg_policies
             WHERE schemaname = 'public' AND cmd = 'INSERT'
             AND tablename IN ('profiles', 'users', 'memberships')
             AND policyname IN ('Users can insert own profile', 'Users can insert own user record', 'Users can insert memberships')) = 3
        ) THEN '🎉 SIGNUP SYSTEM READY - All components verified!'
        ELSE '⚠️  ISSUES DETECTED - Check results above'
    END as readiness_status;