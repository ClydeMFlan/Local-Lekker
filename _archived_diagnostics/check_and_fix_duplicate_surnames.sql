-- Check current name and surname for trusted partners
SELECT 
    id,
    name,
    surname,
    email,
    CONCAT(name, ' ', surname) as full_name
FROM profiles
WHERE role = 'trusted_partner'
ORDER BY email;

-- Fix: The name column contains "FirstName Surname" but should only contain "FirstName"
-- The surname column is correct

-- Fix Lene's name (remove surname from name field)
UPDATE profiles 
SET name = 'Lene'
WHERE email = 'houselillian5@gmail.com' AND name = 'Lene  Momberg';

-- Fix Michele's name (remove surname from name field)
UPDATE profiles 
SET name = 'Michele'
WHERE email = 'michelebekker007@gmail.com' AND name = 'Michele Coetzer';

-- Check again after update
SELECT 
    id,
    name,
    surname,
    email,
    CONCAT(name, ' ', surname) as full_name
FROM profiles
WHERE role = 'trusted_partner'
ORDER BY email;
