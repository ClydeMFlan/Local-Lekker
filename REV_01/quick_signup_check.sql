-- Quick check for critical signup issues
-- Run this in Supabase SQL Editor

-- Check if key tables exist
SELECT '=== TABLES IN PUBLIC SCHEMA ===' as info;
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- Check INSERT policies for signup-critical tables
SELECT '=== INSERT POLICIES FOR SIGNUP TABLES ===' as info;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND cmd = 'INSERT'
  AND tablename IN ('profiles', 'users', 'memberships')
ORDER BY tablename, policyname;

-- Check if RLS is enabled on critical tables
SELECT '=== RLS STATUS FOR SIGNUP TABLES ===' as info;
SELECT
    t.schemaname,
    t.tablename,
    CASE WHEN c.relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END as rls_status
FROM pg_tables t
LEFT JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public'
  AND t.tablename IN ('profiles', 'users', 'memberships')
ORDER BY t.tablename;

-- Check if key tables have the expected structure
SELECT '=== TABLE EXISTS CHECK ===' as info;
SELECT
    'profiles' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT
    'users' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users') THEN 'EXISTS' ELSE 'MISSING' END as status
UNION ALL
SELECT
    'memberships' as table_name,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'memberships') THEN 'EXISTS' ELSE 'MISSING' END as status;