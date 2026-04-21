-- =============================================================================
-- CLEANUP NOTIFICATIONS RLS POLICIES - REMOVE DUPLICATES
-- =============================================================================
-- This script removes all duplicate INSERT policies and keeps only one
-- =============================================================================

-- Drop ALL existing INSERT policies (including the duplicate)
DROP POLICY IF EXISTS "Authenticated members can insert notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_insert_policy" ON notifications;
DROP POLICY IF EXISTS "Allow insert for any user" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_insert_authenticated" ON notifications;
DROP POLICY IF EXISTS "Allow authenticated users to create notifications" ON notifications;

-- Create ONE single, clean INSERT policy
-- This allows any authenticated user to create notifications for any user
-- (necessary for trusted partners to notify members)
CREATE POLICY "notifications_insert_authenticated" ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Verify only ONE INSERT policy exists
SELECT 
    policyname,
    cmd,
    roles,
    with_check
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;
