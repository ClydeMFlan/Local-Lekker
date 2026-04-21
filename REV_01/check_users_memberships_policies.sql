-- Check RLS policies for users and memberships tables
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('users', 'memberships')
ORDER BY tablename, policyname;