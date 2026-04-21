-- Deep diagnostic for notifications RLS issue
-- Check everything that could block INSERT even with policies

-- 1. Check if RLS is actually enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename = 'notifications';

-- 2. Check table ownership
SELECT t.tablename, t.tableowner, c.relacl
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE t.schemaname = 'public' AND t.tablename = 'notifications';

-- 3. Check ALL policies (including inherited or system policies)
SELECT *
FROM pg_policies
WHERE tablename = 'notifications';

-- 4. Check grants on the table
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public' 
  AND table_name = 'notifications';

-- 5. Check if there are any RESTRICTIVE policies (these are AND conditions)
SELECT policyname, permissive
FROM pg_policies
WHERE tablename = 'notifications' 
  AND permissive = 'RESTRICTIVE';

-- 6. Check the actual policy definitions with full details
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN qual
        ELSE 'NULL (no USING clause)'
    END as using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN with_check
        ELSE 'NULL (no WITH CHECK clause)'
    END as with_check_clause
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY cmd, policyname;
