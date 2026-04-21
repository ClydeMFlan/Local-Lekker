-- =============================================================================
-- VERIFY NOTIFICATIONS RLS POLICIES
-- =============================================================================
-- This script verifies all RLS policies on the notifications table
-- =============================================================================

-- Check if RLS is enabled
SELECT 
    tablename,
    rowsecurity as "RLS Enabled"
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'notifications';

-- Check all policies on notifications table
SELECT 
    policyname as "Policy Name",
    cmd as "Command",
    roles as "Roles",
    CASE 
        WHEN qual IS NULL THEN 'N/A'
        ELSE qual::text
    END as "USING clause",
    CASE 
        WHEN with_check IS NULL THEN 'N/A'
        WHEN with_check::text = 'true' THEN 'true (allows all)'
        ELSE with_check::text
    END as "WITH CHECK clause"
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;
