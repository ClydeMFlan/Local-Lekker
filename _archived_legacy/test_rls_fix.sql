-- Test SQL to verify RLS policy fixes

-- Check that policies exist and contain wrapped auth.uid() calls
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('trusted_partner_bank_accounts', 'bill_approvals')
ORDER BY tablename, policyname;

-- Test policy qualification expressions contain '(SELECT auth.uid())'
SELECT policyname, 
       CASE WHEN qual LIKE '%(SELECT auth.uid())%' THEN 'OPTIMIZED' ELSE 'NOT OPTIMIZED' END as optimization_status
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('trusted_partner_bank_accounts', 'bill_approvals')
AND qual IS NOT NULL;

-- Verify triggers exist
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'public' 
AND event_object_table IN ('trusted_partner_bank_accounts', 'bill_approvals')
ORDER BY event_object_table, trigger_name;
