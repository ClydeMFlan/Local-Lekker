-- =============================================================================
-- DEBUG NOTIFICATIONS RLS - CURRENT STATE
-- =============================================================================
-- Run this to see the EXACT current state of notifications RLS
-- =============================================================================

-- 1. Check if RLS is enabled
SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity THEN 'ENABLED'
        ELSE 'DISABLED'
    END as rls_status
FROM pg_tables t
JOIN pg_class c ON t.tablename = c.relname
WHERE t.schemaname = 'public' 
  AND t.tablename = 'notifications';

-- 2. Check ALL policies on notifications table
SELECT 
    policyname,
    cmd as command,
    CASE 
        WHEN permissive = 'PERMISSIVE' THEN 'PERMISSIVE'
        ELSE 'RESTRICTIVE'
    END as policy_type,
    roles,
    COALESCE(qual::text, 'No USING clause') as using_clause,
    COALESCE(with_check::text, 'No WITH CHECK clause') as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- 3. Check if there's ANY INSERT policy at all
SELECT COUNT(*) as insert_policy_count
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND cmd = 'INSERT';

-- 4. Test auth context
SELECT 
    auth.uid() as current_user_id,
    auth.role() as current_role;

-- 5. Show table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;
