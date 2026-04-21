-- Check businesses table structure
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'businesses';

-- Check the business for houselillian5@gmail.com
SELECT 
    b.*
FROM businesses b
JOIN profiles p ON b.owner_member_id = p.id
WHERE p.email = 'houselillian5@gmail.com';
