-- Check what email addresses exist in profiles
SELECT 
  email,
  name,
  surname,
  role,
  id
FROM profiles
WHERE email LIKE '%clyde%'
OR email LIKE '%momsies%'
ORDER BY email;
