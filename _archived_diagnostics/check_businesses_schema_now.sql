-- Check businesses table structure
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_name = 'businesses'
ORDER BY ordinal_position;

-- Also show the Momsies business data
SELECT * FROM businesses WHERE name = 'Momsies';
