-- Check trusted_partners table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'trusted_partners'
    AND table_schema = 'public'
ORDER BY ordinal_position;
