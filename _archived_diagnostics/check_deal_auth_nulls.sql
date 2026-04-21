-- Check deal_authorizations data for null fields
SELECT 
  id,
  member_id,
  business_id,
  trusted_partner_id,
  discount_id,
  status,
  authorization_type
FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 5;
