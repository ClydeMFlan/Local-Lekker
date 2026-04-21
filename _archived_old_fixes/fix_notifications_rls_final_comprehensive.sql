-- =============================================================================
-- FIX NOTIFICATIONS RLS - COMPREHENSIVE AND FINAL
-- =============================================================================
-- This script completely fixes the notifications RLS policies to allow
-- cross-user notifications (e.g., trusted partners notifying members)
-- =============================================================================

-- Step 1: Ensure RLS is enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Step 2: Drop ALL existing policies to start completely fresh
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
        EXECUTE format('DROP POLICY IF EXISTS %I ON notifications', policy_record.policyname);
    END LOOP;
END $$;

-- Step 3: Create THREE simple policies

-- SELECT Policy: Users can only see their own notifications
CREATE POLICY "notifications_select_own" 
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT Policy: ANY authenticated user can insert notifications for ANY user
-- This is critical for cross-user notifications
CREATE POLICY "notifications_insert_all" 
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- UPDATE Policy: Users can only update their own notifications
CREATE POLICY "notifications_update_own" 
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Step 4: Verify the policies
SELECT 
    '=== NOTIFICATIONS RLS POLICIES ===' as info,
    policyname,
    cmd,
    roles,
    COALESCE(qual::text, 'No USING') as using_expr,
    COALESCE(with_check::text, 'No WITH CHECK') as with_check_expr
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- Step 5: Test INSERT with a dummy query (will fail but shows if RLS allows it)
-- Comment this out if you don't want to test
/*
DO $$
DECLARE
    test_user_id uuid;
BEGIN
    -- Get a real user ID from profiles table
    SELECT id INTO test_user_id 
    FROM profiles 
    LIMIT 1;
    
    IF test_user_id IS NOT NULL THEN
        RAISE NOTICE 'Testing INSERT policy with user_id: %', test_user_id;
        
        -- This should work if the policy is correct
        -- We'll rollback so it doesn't actually insert
        BEGIN
            INSERT INTO notifications (user_id, title, message, type, is_read)
            VALUES (test_user_id, 'Test Notification', 'This is a test', 'info', false);
            
            RAISE NOTICE 'INSERT test PASSED - Policy allows cross-user notifications';
            RAISE EXCEPTION 'Rolling back test insert';
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLSTATE = 'P0001' AND SQLERRM = 'Rolling back test insert' THEN
                    RAISE NOTICE 'Test completed successfully - rolling back';
                ELSE
                    RAISE NOTICE 'INSERT test FAILED - %', SQLERRM;
                END IF;
        END;
    END IF;
END $$;
*/

-- Success message
SELECT '✅ Notifications RLS policies have been fixed!' as status;
SELECT '✅ Authenticated users can now create notifications for other users' as status;
SELECT '✅ Users can only see and update their own notifications' as status;
