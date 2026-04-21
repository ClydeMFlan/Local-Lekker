-- Check for pending deal authorizations
SELECT 
  'deal_authorizations' as table_name,
  da.id,
  da.member_id,
  da.business_id,
  da.status,
  da.created_at,
  p.email as member_email,
  b.name as business_name,
  b.owner_member_id as business_owner_id
FROM deal_authorizations da
LEFT JOIN profiles p ON da.member_id = p.user_id
LEFT JOIN businesses b ON da.business_id = b.id
WHERE da.status = 'pending'
ORDER BY da.created_at DESC;

-- Check for pending bill approvals
SELECT 
  'bill_approvals' as table_name,
  ba.id,
  ba.partner_id,
  ba.bill_id,
  ba.status,
  ba.created_at
FROM bill_approvals ba
WHERE ba.status = 'pending'
ORDER BY ba.created_at DESC;

-- Check businesses for trusted partner
SELECT 
  id as business_id,
  name as business_name,
  owner_member_id,
  created_at
FROM businesses
WHERE owner_member_id IN (
  SELECT user_id 
  FROM profiles 
  WHERE email = 'houselillian5@gmail.com'
);
