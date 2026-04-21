-- Check all fields available in deal_receipts table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'deal_receipts'
ORDER BY ordinal_position;

-- Check all fields available in deal_authorizations table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- Check all fields available in trusted_partner_discounts table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;

-- Check actual data in deal_receipts for recent receipts
SELECT 
    dr.*
FROM deal_receipts dr
ORDER BY dr.created_at DESC
LIMIT 5;

-- Check actual data in deal_authorizations with all fields
SELECT 
    da.*
FROM deal_authorizations da
ORDER BY da.created_at DESC
LIMIT 5;

-- Check what discount information is available
SELECT 
    tpd.*
FROM trusted_partner_discounts tpd
LIMIT 5;

-- Check the JOIN between tables to see what data is available for savings calculation
SELECT 
    dr.*,
    da.*,
    tpd.*
FROM deal_receipts dr
LEFT JOIN deal_authorizations da ON dr.deal_authorization_id = da.id
LEFT JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
ORDER BY dr.created_at DESC
LIMIT 5;
