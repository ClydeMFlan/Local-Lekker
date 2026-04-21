-- =============================================================================
-- CHECK WHY RLS IS STILL FAILING
-- =============================================================================
-- This investigates what might be blocking the INSERT
-- =============================================================================

-- 1. Check if RLS is actually enabled
SELECT 
    '1. RLS Status' as check_number,
    relname as table_name,
    CASE 
        WHEN relrowsecurity THEN '✅ ENABLED'
        ELSE '❌ DISABLED'
    END as rls_status,
    CASE 
        WHEN relforcerowsecurity THEN '⚠️ FORCED (overrides bypass)'
        ELSE 'Normal'
    END as force_status
FROM pg_class
WHERE relname = 'notifications';

-- 2. List ALL policies (including hidden ones)
SELECT 
    '2. All Policies' as check_number,
    policyname,
    cmd,
    permissive,
    roles,
    qual::text as using_clause,
    with_check::text as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- 3. Check if there are any RESTRICTIVE policies (these override PERMISSIVE)
SELECT 
    '3. Restrictive Policies' as check_number,
    policyname,
    cmd,
    with_check::text
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND permissive = 'RESTRICTIVE';

-- 4. Check current auth context
SELECT 
    '4. Auth Context' as check_number,
    auth.uid() as current_user_id,
    auth.role() as current_role,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN '✅ Authenticated'
        ELSE '❌ Not authenticated'
    END as auth_status;

-- 5. Check if there are any FOREIGN KEY constraints that might be failing
SELECT 
    '5. Foreign Keys' as check_number,
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint
WHERE conrelid = 'notifications'::regclass;

-- 6. Check table structure
SELECT 
    '6. Table Columns' as check_number,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- 7. Check if there are any triggers that might be interfering
SELECT 
    '7. Triggers' as check_number,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'notifications';

-- 8. Try to see what the RLS policy evaluates to
EXPLAIN (VERBOSE, COSTS OFF)
SELECT * FROM notifications WHERE user_id = auth.uid();

-- 9. Check if there are any roles with bypassrls privilege
SELECT 
    '9. Bypass RLS Roles' as check_number,
    rolname,
    rolsuper,
    rolbypassrls
FROM pg_roles
WHERE rolbypassrls = true;

-- 10. Test INSERT as current user (will fail but shows the error)
DO $$
DECLARE
    current_user_id uuid;
    other_user_id uuid;
BEGIN
    -- Get current auth user
    current_user_id := auth.uid();
    
    -- Get another user
    SELECT id INTO other_user_id
    FROM profiles
    WHERE id != current_user_id
    LIMIT 1;
    
    RAISE NOTICE '10. Testing INSERT with auth.uid(): %', current_user_id;
    RAISE NOTICE '    Trying to insert for user_id: %', other_user_id;
    
    -- Try to insert
    BEGIN
        INSERT INTO notifications (user_id, title, message, type, is_read)
        VALUES (other_user_id, 'Test', 'Test message', 'info', false);
        
        RAISE NOTICE '    ✅ INSERT SUCCEEDED!';
        
        -- Clean up
        DELETE FROM notifications WHERE user_id = other_user_id AND title = 'Test';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '    ❌ INSERT FAILED: %', SQLERRM;
        RAISE NOTICE '    SQLSTATE: %', SQLSTATE;
    END;
END $$;

-- 11. Summary
SELECT 
    '=== SUMMARY ===' as final_check,
    (SELECT relrowsecurity FROM pg_class WHERE relname = 'notifications') as rls_enabled,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications') as total_policies,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications' AND cmd = 'INSERT') as insert_policies,
    (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'notifications' AND permissive = 'RESTRICTIVE') as restrictive_policies,
    auth.uid() as current_user,
    auth.role() as current_role;
