-- =====================================================
-- VERIFY is_tp_member COLUMN EXISTS
-- Check if the column is present and has data
-- =====================================================

-- Check if column exists
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'profiles' 
  AND column_name = 'is_tp_member';

-- Count members by is_tp_member status
SELECT 
  'Total members' as category,
  COUNT(*) as count
FROM profiles
WHERE role = 'member'
UNION ALL
SELECT 
  'TP Members (is_tp_member = true)',
  COUNT(*)
FROM profiles
WHERE role = 'member' AND is_tp_member = true
UNION ALL
SELECT 
  'Regular Members (is_tp_member = false/null)',
  COUNT(*)
FROM profiles
WHERE role = 'member' AND (is_tp_member = false OR is_tp_member IS NULL);

-- Show sample TP members
SELECT 
  id,
  name,
  surname,
  email,
  is_tp_member,
  verified,
  created_at
FROM profiles
WHERE role = 'member' AND is_tp_member = true
ORDER BY created_at DESC
LIMIT 10;
