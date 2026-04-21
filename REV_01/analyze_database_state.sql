-- Comprehensive database schema and migration status check
-- Run this in Supabase SQL Editor to analyze current state

-- 1. Check all tables in the public schema
SELECT '=== TABLES IN PUBLIC SCHEMA ===' as section;
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

-- 2. Check RLS policies for all tables
SELECT '=== RLS POLICIES FOR ALL TABLES ===' as section;
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 3. Skip migration history check (known to be corrupted from CLI output)
SELECT '=== MIGRATION HISTORY ===' as section;
SELECT 'Migration history is corrupted (all migrations show as reverted except one)' as status;
SELECT 'Focus on checking actual database schema and policies instead' as recommendation;

-- Alternative: Check for any migration-related tables
SELECT '=== MIGRATION-RELATED TABLES ===' as section;
SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname = 'public' AND tablename LIKE '%migration%'
ORDER BY tablename;

-- 4. Check table structures using information_schema (key tables)
SELECT '=== PROFILES TABLE STRUCTURE ===' as section;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;

SELECT '=== USERS TABLE STRUCTURE ===' as section;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'users'
ORDER BY ordinal_position;

SELECT '=== MEMBERSHIPS TABLE STRUCTURE ===' as section;
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'memberships'
ORDER BY ordinal_position;