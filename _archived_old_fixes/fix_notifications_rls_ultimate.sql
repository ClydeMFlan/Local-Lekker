-- ULTIMATE FIX for notifications RLS
-- Root cause: INSERT policies need WITH CHECK but should NOT have USING clause
-- USING clause is for SELECT/UPDATE/DELETE, not INSERT

-- Step 1: Grant full permissions to authenticated role
GRANT ALL ON TABLE notifications TO authenticated;
-- Note: Sequence grant removed - not needed if id column has DEFAULT

-- Step 2: Completely drop ALL policies (even ones we might have missed)
DO $$ 
DECLARE
    pol record;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'notifications'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON notifications', pol.policyname);
    END LOOP;
END $$;

-- Step 3: Disable and re-enable RLS to clear any cached state
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 4: Create INSERT policy - NO USING clause, only WITH CHECK
-- This is critical: INSERT operations should ONLY have WITH CHECK
CREATE POLICY notifications_insert_policy
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Step 5: Create SELECT policy - ONLY USING clause for reading
CREATE POLICY notifications_select_policy
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Step 6: Create UPDATE policy - BOTH USING and WITH CHECK
CREATE POLICY notifications_update_policy
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Step 7: Create DELETE policy - ONLY USING clause
CREATE POLICY notifications_delete_policy
ON notifications
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Final verification
SELECT 
    '=== GRANTS ===' as section,
    grantee,
    string_agg(privilege_type, ', ') as privileges
FROM information_schema.role_table_grants
WHERE table_schema = 'public' 
  AND table_name = 'notifications'
GROUP BY grantee;

SELECT 
    '=== RLS STATUS ===' as section,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'notifications';

SELECT 
    '=== POLICIES ===' as section,
    policyname,
    cmd as operation,
    permissive,
    COALESCE(qual, '(none)') as using_clause,
    COALESCE(with_check::text, '(none)') as with_check_clause
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY cmd, policyname;
