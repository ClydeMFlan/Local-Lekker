-- Check the is_active status of all discounts
-- This will help identify if the toggle UI is actually updating the database

SELECT 
    id,
    name,
    is_active,
    trusted_partner_id,
    created_at,
    updated_at
FROM trusted_partner_discounts
ORDER BY created_at DESC
LIMIT 20;

-- Check specifically for "Summer" discounts mentioned in screenshot
SELECT 
    id,
    name,
    is_active,
    trusted_partner_id,
    business_id,
    percentage,
    fixed_amount
FROM trusted_partner_discounts
WHERE name ILIKE '%summer%'
ORDER BY created_at DESC;

-- Count active vs inactive discounts
SELECT 
    is_active,
    COUNT(*) as count
FROM trusted_partner_discounts
GROUP BY is_active;
