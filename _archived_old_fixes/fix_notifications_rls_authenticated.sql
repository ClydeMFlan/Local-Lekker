-- Fix notifications RLS for authenticated role
-- The app is using authenticated role (confirmed in JWT: "role":"authenticated")
-- Current policies were for public role which don't apply

-- Drop all existing policies
DROP POLICY IF EXISTS notifications_insert_all ON notifications;
DROP POLICY IF EXISTS notifications_select_own ON notifications;
DROP POLICY IF EXISTS notifications_update_own ON notifications;
DROP POLICY IF EXISTS notifications_delete_own ON notifications;

-- Create INSERT policy for authenticated role (permissive for deal authorizations)
CREATE POLICY notifications_insert_authenticated
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Create SELECT policy for authenticated role (users can see their own notifications)
CREATE POLICY notifications_select_authenticated
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Create UPDATE policy for authenticated role (users can update their own notifications)
CREATE POLICY notifications_update_authenticated
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid());

-- Create DELETE policy for authenticated role (optional - users can delete their own)
CREATE POLICY notifications_delete_authenticated
ON notifications
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Verify policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY policyname;
