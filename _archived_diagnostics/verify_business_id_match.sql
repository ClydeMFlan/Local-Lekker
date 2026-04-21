-- Check if the trusted_partner_id matches the business owned by houselillian5@gmail.com
SELECT 
    b.id as business_id,
    b.business_name,
    b.owner_member_id,
    p.email as owner_email
FROM businesses b
JOIN profiles p ON b.owner_member_id = p.id
WHERE p.email = 'houselillian5@gmail.com';

-- Check what the trusted_partner_id in deal_authorizations actually refers to
-- (it should be the business_id)
SELECT 
    'Deal Authorization trusted_partner_id' as label,
    '8692b21b-42c4-43fd-af23-fb0f37bc4068' as id;
