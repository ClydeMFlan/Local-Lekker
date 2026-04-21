-- Check if trusted_partner_discounts table has RLS enabled and what policies exist
SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'trusted_partner_discounts';

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies WHERE tablename = 'trusted_partner_discounts'
ORDER BY policyname;
