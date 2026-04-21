-- =============================================================================
-- RE-ENABLE NOTIFICATIONS RLS WITH CORRECT POLICY
-- =============================================================================
-- This re-enables RLS with a policy that allows authenticated users to insert
-- notifications for any user (necessary for cross-user notifications)
-- =============================================================================

-- Re-enable RLS on notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "notifications_insert_policy" ON notifications;
DROP POLICY IF EXISTS "Allow insert for any user" ON notifications;
DROP POLICY IF EXISTS "Authenticated users can insert notifications" ON notifications;

-- Create INSERT policy - any authenticated user can insert for any user_id
CREATE POLICY "notifications_insert_authenticated" ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Keep SELECT policy - users can only see their own notifications
CREATE POLICY "notifications_select_own" ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Keep UPDATE policy - users can only update their own notifications
CREATE POLICY "notifications_update_own" ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Verify the policies
SELECT policyname, cmd, permissive, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'notifications'
ORDER BY cmd, policyname;
