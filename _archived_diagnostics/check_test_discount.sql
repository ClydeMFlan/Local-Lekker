-- Check the test discount we just created
SELECT 
  id,
  business_id,
  trusted_partner_id,
  name,
  description,
  item_name,
  percentage,
  is_active
FROM trusted_partner_discounts
WHERE name = 'Test Discount'
ORDER BY created_at DESC
LIMIT 1;
