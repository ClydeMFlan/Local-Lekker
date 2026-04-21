-- =============================================================================
-- VERIFY NOTIFICATION RLS FIX
-- =============================================================================
-- Run this AFTER applying the fix to verify everything works
-- =============================================================================

-- 1. Check RLS is enabled
SELECT 
    'RLS Status' as check_type,
    CASE 
        WHEN relrowsecurity THEN '✅ ENABLED'
        ELSE '❌ DISABLED (BAD!)'
    END as status
FROM pg_class
WHERE relname = 'notifications';

-- 2. Count policies by type
SELECT 
    'Policy Count' as check_type,
    cmd as command,
    COUNT(*) as count,
    CASE 
        WHEN cmd = 'SELECT' AND COUNT(*) = 1 THEN '✅ Correct'
        WHEN cmd = 'INSERT' AND COUNT(*) = 1 THEN '✅ Correct'
        WHEN cmd = 'UPDATE' AND COUNT(*) = 1 THEN '✅ Correct'
        ELSE '❌ Wrong count!'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
GROUP BY cmd
ORDER BY cmd;

-- 3. Verify INSERT policy allows cross-user notifications
SELECT 
    'INSERT Policy Check' as check_type,
    policyname,
    with_check::text,
    CASE 
        WHEN with_check::text LIKE '%auth.uid() IS NOT NULL%' THEN '✅ Allows cross-user notifications'
        WHEN with_check::text LIKE '%user_id = auth.uid%' THEN '❌ TOO RESTRICTIVE - Will fail!'
        ELSE '⚠️ Unknown policy'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND cmd = 'INSERT';

-- 4. Verify SELECT policy restricts to own notifications
SELECT 
    'SELECT Policy Check' as check_type,
    policyname,
    qual::text as using_clause,
    CASE 
        WHEN qual::text LIKE '%user_id = auth.uid%' THEN '✅ Users see only their own'
        WHEN qual::text LIKE '%true%' THEN '❌ TOO PERMISSIVE - Users can see all!'
        ELSE '⚠️ Unknown policy'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND cmd = 'SELECT';

-- 5. Verify UPDATE policy restricts to own notifications
SELECT 
    'UPDATE Policy Check' as check_type,
    policyname,
    qual::text as using_clause,
    with_check::text,
    CASE 
        WHEN qual::text LIKE '%user_id = auth.uid%' 
         AND with_check::text LIKE '%user_id = auth.uid%' THEN '✅ Users update only their own'
        ELSE '❌ Policy may be wrong'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND cmd = 'UPDATE';

-- 6. Full policy list for manual review
SELECT 
    '=== ALL POLICIES DETAIL ===' as info,
    policyname,
    cmd,
    permissive,
    roles,
    COALESCE(qual::text, 'No USING') as using_clause,
    COALESCE(with_check::text, 'No WITH CHECK') as with_check_clause
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;

-- 7. Check for any restrictive policies that might block
SELECT 
    'Restrictive Policies Check' as check_type,
    COUNT(*) as count,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ No restrictive policies'
        ELSE '❌ Has restrictive policies - may cause issues'
    END as status
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
  AND permissive = 'RESTRICTIVE';

-- 8. Test current auth context
SELECT 
    'Current Auth Context' as check_type,
    auth.uid() as user_id,
    auth.role() as role,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN '✅ Authenticated'
        ELSE '❌ Not authenticated'
    END as status;

-- 9. Summary check
SELECT 
    '=== SUMMARY ===' as final_check,
    CASE 
        WHEN 
            -- RLS enabled
            (SELECT relrowsecurity FROM pg_class WHERE relname = 'notifications') = true
            AND
            -- Exactly 3 policies
            (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'notifications') = 3
            AND
            -- INSERT policy allows cross-user
            (SELECT with_check::text FROM pg_policies WHERE schemaname = 'public' AND tablename = 'notifications' AND cmd = 'INSERT') LIKE '%auth.uid() IS NOT NULL%'
            AND
            -- SELECT policy restricts to own
            (SELECT qual::text FROM pg_policies WHERE schemaname = 'public' AND tablename = 'notifications' AND cmd = 'SELECT') LIKE '%user_id = auth.uid%'
            AND
            -- No restrictive policies
            (SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'notifications' AND permissive = 'RESTRICTIVE') = 0
        THEN '✅✅✅ ALL CHECKS PASSED - Ready to test!'
        ELSE '❌ Some checks failed - review above details'
    END as overall_status;
