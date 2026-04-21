-- Check businesses table structure and current That Old Oak row
SELECT 
    id,
    owner_member_id,
    name,
    logo_url,
    updated_at,
    created_at
FROM businesses 
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8'
   OR name = 'That Old Oak';
