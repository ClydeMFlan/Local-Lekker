SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'profiles';
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual FROM pg_policies WHERE tablename = 'profiles' ORDER BY policyname;
