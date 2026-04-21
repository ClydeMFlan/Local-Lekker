-- =====================================================
-- MANUAL CLEANUP: Delete user from auth.users
-- =====================================================
-- User: 09e95df7-0500-437a-b732-15a7789b390b
-- Email: thecraftsmanel@gmail.com
-- 
-- This user's data was already deleted by admin_delete_member_data()
-- Now we need to remove them from auth.users
-- =====================================================

DELETE FROM auth.users 
WHERE id = '09e95df7-0500-437a-b732-15a7789b390b';

-- Verify deletion
SELECT 
  CASE 
    WHEN EXISTS(SELECT 1 FROM auth.users WHERE id = '09e95df7-0500-437a-b732-15a7789b390b')
    THEN '❌ User still exists in auth.users'
    ELSE '✓ User successfully deleted from auth.users'
  END as result;
