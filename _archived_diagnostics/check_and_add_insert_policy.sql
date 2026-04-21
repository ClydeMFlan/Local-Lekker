-- Check if INSERT policy exists for deal_authorizations
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'deal_authorizations'
ORDER BY policyname;

-- If the INSERT policy is missing, add it
CREATE POLICY IF NOT EXISTS "Members can insert their own authorizations" ON deal_authorizations
    FOR INSERT WITH CHECK ((SELECT auth.uid()) = member_id);