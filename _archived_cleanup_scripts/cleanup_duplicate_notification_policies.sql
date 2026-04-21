-- =============================================================================
-- CLEAN UP DUPLICATE NOTIFICATION POLICIES
-- =============================================================================
-- Remove duplicate SELECT and UPDATE policies to avoid conflicts
-- =============================================================================

-- Drop all existing SELECT policies
DROP POLICY IF EXISTS "Users can view their notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_select_own" ON notifications;

-- Drop all existing UPDATE policies
DROP POLICY IF EXISTS "Users can update their notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_update_own" ON notifications;

-- Create single SELECT policy - users can only see their own notifications
CREATE POLICY "notifications_select_own" ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Create single UPDATE policy - users can only update their own notifications
CREATE POLICY "notifications_update_own" ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Verify the final policies
SELECT policyname, cmd, permissive, roles, qual, with_check
FROM pg_policies
WHERE schemaname = 'public' AND tablename = 'notifications'
ORDER BY cmd, policyname;
