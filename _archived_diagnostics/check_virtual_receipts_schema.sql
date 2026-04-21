-- Check virtual_receipts table structure
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'virtual_receipts'
ORDER BY ordinal_position;
