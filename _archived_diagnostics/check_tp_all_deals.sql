-- Check all discounts for the trusted partner with user ID 78e67dc8-583b-4fe0-84e6-aa4d0c55a92e
-- (This is the TP who has the "Summer" deals based on previous queries)

SELECT 
    id,
    name,
    description,
    item_name,
    percentage,
    fixed_amount,
    is_active,
    created_at,
    updated_at,
    trusted_partner_id,
    business_id
FROM trusted_partner_discounts
WHERE trusted_partner_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e'
ORDER BY created_at DESC;

-- Also check for the other TP shown in previous queries
SELECT 
    id,
    name,
    description,
    item_name,
    percentage,
    fixed_amount,
    is_active,
    created_at,
    updated_at,
    trusted_partner_id,
    business_id
FROM trusted_partner_discounts
WHERE trusted_partner_id = 'aec73b0f-f8e1-4f1a-9c55-b1d6c4df808b'
ORDER BY created_at DESC;

-- Count total deals per TP
SELECT 
    trusted_partner_id,
    COUNT(*) as total_deals,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) as active_deals,
    SUM(CASE WHEN NOT is_active THEN 1 ELSE 0 END) as inactive_deals
FROM trusted_partner_discounts
GROUP BY trusted_partner_id
ORDER BY total_deals DESC;
