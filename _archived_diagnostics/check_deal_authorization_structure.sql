-- Check the structure of deal_authorizations table
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'deal_authorizations';

-- Check recent deal_authorizations records
SELECT * FROM deal_authorizations ORDER BY created_at DESC LIMIT 5;

-- Check the trusted_partner_discounts table structure
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'trusted_partner_discounts';
