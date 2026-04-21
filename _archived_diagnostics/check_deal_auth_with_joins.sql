-- Check what the query with joins returns
SELECT 
  da.id,
  da.member_id,
  da.business_id,
  da.discount_id,
  da.status,
  p.name as member_name,
  p.surname as member_surname,
  tpd.name as discount_name,
  tpd.description as discount_description
FROM deal_authorizations da
LEFT JOIN profiles p ON p.id = da.member_id
LEFT JOIN trusted_partner_discounts tpd ON tpd.id = da.discount_id
WHERE da.business_id = '8692b21b-42c4-43fd-af23-fb0f37bc4068'
ORDER BY da.created_at DESC
LIMIT 5;
