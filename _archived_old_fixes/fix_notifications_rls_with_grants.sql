-- Fix notifications RLS - Complete solution with grants
-- The issue: RLS policies exist but table lacks proper grants for authenticated role

-- Step 1: Ensure proper table grants for authenticated role
GRANT ALL ON notifications TO authenticated;
GRANT USAGE ON SEQUENCE notifications_id_seq TO authenticated;

-- Step 2: Drop all existing policies to start fresh
DROP POLICY IF EXISTS notifications_insert_all ON notifications;
DROP POLICY IF EXISTS notifications_insert_authenticated ON notifications;
DROP POLICY IF EXISTS notifications_select_own ON notifications;
DROP POLICY IF EXISTS notifications_select_authenticated ON notifications;
DROP POLICY IF EXISTS notifications_update_own ON notifications;
DROP POLICY IF EXISTS notifications_update_authenticated ON notifications;
DROP POLICY IF EXISTS notifications_delete_own ON notifications;
DROP POLICY IF EXISTS notifications_delete_authenticated ON notifications;

-- Step 3: Ensure RLS is enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 4: Create INSERT policy for authenticated role
-- This allows any authenticated user to insert notifications for other users
-- Critical for deal authorization workflow where member creates notification for trusted partner
CREATE POLICY notifications_insert_authenticated
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Step 5: Create SELECT policy - users can see their own notifications
CREATE POLICY notifications_select_authenticated
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Step 6: Create UPDATE policy - users can update their own notifications (mark as read)
CREATE POLICY notifications_update_authenticated
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Step 7: Create DELETE policy - users can delete their own notifications
CREATE POLICY notifications_delete_authenticated
ON notifications
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Verify the setup
SELECT 'Table Grants:' as check_type;
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' 
  AND table_name = 'notifications'
  AND grantee = 'authenticated';

SELECT 'RLS Enabled:' as check_type;
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'notifications';

SELECT 'Policies:' as check_type;
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    with_check
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;
