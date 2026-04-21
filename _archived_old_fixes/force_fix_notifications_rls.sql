-- =============================================================================
-- FORCE FIX NOTIFICATIONS RLS - NUCLEAR OPTION
-- =============================================================================
-- This completely removes RLS temporarily, then re-enables with correct policy
-- Use this if the previous fix didn't work
-- =============================================================================

-- Step 1: DISABLE RLS completely (temporarily)
ALTER TABLE notifications DISABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL policies (even if they don't exist)
DO $$ 
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'notifications'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON notifications CASCADE', policy_record.policyname);
        RAISE NOTICE 'Dropped policy: %', policy_record.policyname;
    END LOOP;
END $$;

-- Step 3: Verify all policies are gone
SELECT 
    'Remaining policies after drop' as info,
    COUNT(*) as count
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications';

-- Step 4: Re-enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 5: Create ONLY the INSERT policy first (simplest possible)
CREATE POLICY "notifications_insert_any_authenticated" 
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);  -- Simplest possible - just allow any authenticated user

-- Step 6: Add SELECT policy
CREATE POLICY "notifications_select_own" 
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- Step 7: Add UPDATE policy
CREATE POLICY "notifications_update_own" 
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Step 8: Verify policies were created
SELECT 
    '=== POLICIES AFTER RECREATION ===' as info,
    policyname,
    cmd,
    permissive,
    roles,
    COALESCE(with_check::text, 'No WITH CHECK') as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- Step 9: Test that INSERT works
DO $$
DECLARE
    test_notification_id uuid;
BEGIN
    -- Try to insert a test notification (will rollback)
    INSERT INTO notifications (user_id, title, message, type, is_read)
    VALUES (
        (SELECT id FROM profiles LIMIT 1),
        'RLS Test Notification',
        'This is a test to verify RLS allows inserts',
        'info',
        false
    )
    RETURNING id INTO test_notification_id;
    
    RAISE NOTICE '✅ INSERT TEST PASSED - Created notification: %', test_notification_id;
    
    -- Clean up test notification
    DELETE FROM notifications WHERE id = test_notification_id;
    RAISE NOTICE '✅ Cleaned up test notification';
    
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '❌ INSERT TEST FAILED: %', SQLERRM;
    RAISE NOTICE 'SQLSTATE: %', SQLSTATE;
END $$;

-- Step 10: Final status
SELECT 
    '=== FINAL STATUS ===' as info,
    (SELECT relrowsecurity FROM pg_class WHERE relname = 'notifications') as rls_enabled,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications') as total_policies,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications' AND cmd = 'INSERT') as insert_policies;

SELECT '✅ RLS has been completely reset and reconfigured' as final_message;
