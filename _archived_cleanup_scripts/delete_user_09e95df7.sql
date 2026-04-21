-- =====================================================
-- DELETE USER: 09e95df7-0500-437a-b732-15a7789b390b
-- =====================================================

-- First, check what type of user this is
SELECT 
  id, 
  email, 
  name, 
  surname, 
  role,
  created_at
FROM profiles 
WHERE id = '09e95df7-0500-437a-b732-15a7789b390b';

-- If the user is a MEMBER, run this:
-- SELECT admin_delete_member('09e95df7-0500-437a-b732-15a7789b390b');

-- If the user is a TRUSTED_PARTNER, run this:
-- SELECT admin_delete_trusted_partner('09e95df7-0500-437a-b732-15a7789b390b');

-- After checking the role above, uncomment the appropriate line and execute it.
