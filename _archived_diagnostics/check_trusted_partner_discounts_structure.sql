-- Check structure of trusted_partner_discounts table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;
