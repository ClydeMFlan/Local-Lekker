-- Check current columns in trusted_partner_bank_accounts table
SELECT 
    column_name, 
    data_type, 
    is_nullable, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name = 'trusted_partner_bank_accounts' 
ORDER BY ordinal_position;