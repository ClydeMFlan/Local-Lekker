-- Check if business row exists and what fields it has
SELECT 
    id,
    owner_member_id,
    name,
    logo_url,
    category,
    verified,
    created_at,
    updated_at
FROM businesses 
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';

-- If no rows returned, we need to check the trusted_partners table
SELECT 
    user_id,
    business_name,
    verified_status
FROM trusted_partners
WHERE user_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';
