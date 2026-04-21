-- Check the member_id of the deal that was just updated successfully
-- Compare with the member who's trying to make payment

SELECT 
  da.id as deal_id,
  da.member_id,
  da.business_id,
  da.status,
  da.payment_completed_at,
  p.name as member_name,
  p.email as member_email
FROM deal_authorizations da
LEFT JOIN profiles p ON p.id = da.member_id
WHERE da.id = '7911356e-aa66-4516-8bea-1b24b50360ee';

-- Check ALL approved deals and their member IDs
SELECT 
  da.id as deal_id,
  da.member_id,
  da.status,
  da.payment_completed_at,
  p.name as member_name,
  p.email as member_email
FROM deal_authorizations da
LEFT JOIN profiles p ON p.id = da.member_id
WHERE da.status = 'approved'
ORDER BY da.created_at DESC;
