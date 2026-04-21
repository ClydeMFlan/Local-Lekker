-- This is the EXACT query that the app runs
SELECT 
  *,
  trusted_partner_discounts (
    name,
    description,
    percentage,
    fixed_amount
  ),
  profiles!deal_authorizations_member_id_fkey (
    name,
    surname,
    email
  )
FROM deal_authorizations
WHERE business_id = '8692b21b-42c4-43fd-af23-fb0f37bc4068'
ORDER BY created_at DESC
LIMIT 5;
