-- Check RLS policies for businesses table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'businesses'
ORDER BY policyname;