-- Check That Old Oak logo specifically
SELECT 
    b.id,
    b.name,
    b.owner_member_id,
    b.logo_url,
    p.name as owner_name,
    p.email
FROM businesses b
LEFT JOIN profiles p ON b.owner_member_id = p.id
WHERE b.name = 'That Old Oak'
   OR p.email LIKE '%thecraftsmanel%';

-- Verify the logo exists in storage
-- If logo_url is NULL, the logo was never uploaded successfully
