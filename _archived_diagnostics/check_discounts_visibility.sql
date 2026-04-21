-- Check current RLS policies on trusted_partner_discounts table
SELECT schemaname, tablename, rowsecurity FROM pg_tables WHERE tablename = 'trusted_partner_discounts';

SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies WHERE tablename = 'trusted_partner_discounts'
ORDER BY policyname;

-- Also check if there are any discounts in the table
SELECT COUNT(*) as total_discounts FROM trusted_partner_discounts;

-- Check what a member user can see (using a test member ID)
SELECT COUNT(*) as member_visible_discounts FROM trusted_partner_discounts;