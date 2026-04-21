-- Check what deal_authorizations exist and their null fields
SELECT 
  id,
  member_id,
  business_id,
  trusted_partner_id,
  discount_id,
  status,
  authorization_type,
  created_at
FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 10;

-- Also check if there are any businesses for your trusted partner user
SELECT 
  id,
  name,
  owner_member_id
FROM businesses
WHERE owner_member_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'
LIMIT 5;
