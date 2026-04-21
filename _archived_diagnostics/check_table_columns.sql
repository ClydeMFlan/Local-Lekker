-- Check the actual columns in trusted_partner_discounts table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;

-- Check the actual columns in profiles table
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles'
ORDER BY ordinal_position;
