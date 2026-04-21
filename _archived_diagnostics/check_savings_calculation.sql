-- Get user ID first
SELECT id, email, name, surname
FROM profiles
WHERE email = 'clydemflan@gmail.com';

-- Get all receipts with full details for clydemflan@gmail.com
WITH user_info AS (
  SELECT id as user_id
  FROM profiles
  WHERE email = 'clydemflan@gmail.com'
)
SELECT 
    -- Receipt info
    dr.id as receipt_id,
    dr.receipt_number,
    dr.amount as receipt_amount,
    dr.payment_method,
    dr.created_at as receipt_date,
    
    -- Authorization info
    da.id as auth_id,
    da.amount as auth_amount,
    da.bill_data,
    da.notes,
    
    -- Discount info
    tpd.id as discount_id,
    dr.discount_name,
    tpd.is_bill_discount,
    tpd.is_weight_based,
    tpd.percentage,
    tpd.fixed_amount,
    tpd.item_price,
    tpd.bill_discount_data,
    
    -- Business info
    dr.business_name
FROM deal_receipts dr
JOIN user_info ui ON dr.member_id = ui.user_id
LEFT JOIN deal_authorizations da ON dr.deal_authorization_id = da.id
LEFT JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
ORDER BY dr.created_at DESC;

-- Manual calculation breakdown for each receipt
WITH user_info AS (
  SELECT id as user_id
  FROM profiles
  WHERE email = 'clydemflan@gmail.com'
)
SELECT 
    dr.receipt_number,
    dr.business_name,
    dr.discount_name,
    tpd.is_bill_discount,
    tpd.is_weight_based,
    
    -- Show the raw values
    da.amount as final_amount_paid,
    da.bill_data,
    tpd.percentage,
    tpd.fixed_amount,
    tpd.item_price,
    
    -- Calculate what the original amount and savings should be
    CASE 
        -- Bill discount with bill_data
        WHEN tpd.is_bill_discount = true AND da.bill_data IS NOT NULL THEN
            CONCAT('Original: R', (da.bill_data->>'original_bill_amount')::numeric, 
                   ' | Discount: R', (da.bill_data->>'discount_amount')::numeric,
                   ' | Tip: R', COALESCE((da.bill_data->>'tip_amount')::numeric, 0),
                   ' | Paid: R', da.amount)
        
        -- Bill discount without bill_data (old format)
        WHEN tpd.is_bill_discount = true AND da.bill_data IS NULL THEN
            CONCAT('FALLBACK - Paid: R', da.amount, ' | Percentage: ', tpd.percentage, '%')
        
        -- Weight-based item
        WHEN tpd.is_weight_based = true THEN
            CONCAT('Weight: ', da.amount, 'g = ', (da.amount/1000)::numeric(10,3), 'kg',
                   ' | Price/kg: R', tpd.item_price,
                   ' | Total: R', ((da.amount/1000) * tpd.item_price)::numeric(10,2))
        
        -- Regular item with fixed discount
        WHEN tpd.fixed_amount IS NOT NULL THEN
            CONCAT('Qty: ', da.amount, 
                   ' | Price: R', tpd.item_price,
                   ' | Discount: R', tpd.fixed_amount, '/item',
                   ' | Original: R', (da.amount * tpd.item_price)::numeric(10,2),
                   ' | Saved: R', (da.amount * tpd.fixed_amount)::numeric(10,2))
        
        -- Regular item with percentage discount
        WHEN tpd.percentage IS NOT NULL THEN
            CONCAT('Qty: ', da.amount,
                   ' | Price: R', tpd.item_price,
                   ' | Discount: ', tpd.percentage, '%',
                   ' | Original: R', (da.amount * tpd.item_price)::numeric(10,2),
                   ' | Saved: R', (da.amount * tpd.item_price * tpd.percentage / 100)::numeric(10,2))
        
        ELSE 'UNKNOWN TYPE'
    END as calculation_breakdown

FROM deal_receipts dr
JOIN user_info ui ON dr.member_id = ui.user_id
LEFT JOIN deal_authorizations da ON dr.deal_authorization_id = da.id
LEFT JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
ORDER BY dr.created_at DESC;

-- Summary totals - what should it be?
WITH user_info AS (
  SELECT id as user_id
  FROM profiles
  WHERE email = 'clydemflan@gmail.com'
),
receipt_details AS (
  SELECT 
    dr.id,
    tpd.is_bill_discount,
    tpd.is_weight_based,
    da.amount as final_amount,
    da.bill_data,
    tpd.percentage,
    tpd.fixed_amount,
    tpd.item_price
  FROM deal_receipts dr
  JOIN user_info ui ON dr.member_id = ui.user_id
  LEFT JOIN deal_authorizations da ON dr.deal_authorization_id = da.id
  LEFT JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
)
SELECT 
    COUNT(*) as total_receipts,
    
    -- Bill discounts with bill_data
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN (bill_data->>'original_bill_amount')::numeric 
        ELSE 0 
    END) as bill_discount_original_total,
    
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN (bill_data->>'discount_amount')::numeric 
        ELSE 0 
    END) as bill_discount_savings,
    
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN COALESCE((bill_data->>'tip_amount')::numeric, 0)
        ELSE 0 
    END) as bill_discount_tips,
    
    -- Item-based deals
    SUM(CASE 
        WHEN is_bill_discount = false OR is_bill_discount IS NULL
        THEN 
            CASE 
                WHEN is_weight_based = true THEN (final_amount / 1000) * item_price
                ELSE final_amount * item_price
            END
        ELSE 0 
    END) as item_deals_original_total,
    
    SUM(CASE 
        WHEN is_bill_discount = false OR is_bill_discount IS NULL
        THEN 
            CASE 
                WHEN is_weight_based = true AND fixed_amount IS NOT NULL 
                    THEN (final_amount / 1000) * fixed_amount
                WHEN is_weight_based = true AND percentage IS NOT NULL 
                    THEN (final_amount / 1000) * item_price * percentage / 100
                WHEN fixed_amount IS NOT NULL 
                    THEN final_amount * fixed_amount
                WHEN percentage IS NOT NULL 
                    THEN final_amount * item_price * percentage / 100
                ELSE 0
            END
        ELSE 0 
    END) as item_deals_savings,
    
    -- Grand totals
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN (bill_data->>'original_bill_amount')::numeric 
        WHEN is_bill_discount = false OR is_bill_discount IS NULL
        THEN 
            CASE 
                WHEN is_weight_based = true THEN (final_amount / 1000) * item_price
                ELSE final_amount * item_price
            END
        ELSE 0 
    END) as grand_total_original,
    
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN (bill_data->>'discount_amount')::numeric 
        WHEN is_bill_discount = false OR is_bill_discount IS NULL
        THEN 
            CASE 
                WHEN is_weight_based = true AND fixed_amount IS NOT NULL 
                    THEN (final_amount / 1000) * fixed_amount
                WHEN is_weight_based = true AND percentage IS NOT NULL 
                    THEN (final_amount / 1000) * item_price * percentage / 100
                WHEN fixed_amount IS NOT NULL 
                    THEN final_amount * fixed_amount
                WHEN percentage IS NOT NULL 
                    THEN final_amount * item_price * percentage / 100
                ELSE 0
            END
        ELSE 0 
    END) as grand_total_savings,
    
    SUM(CASE 
        WHEN is_bill_discount = true AND bill_data IS NOT NULL 
        THEN COALESCE((bill_data->>'tip_amount')::numeric, 0)
        ELSE 0 
    END) as grand_total_tips

FROM receipt_details;
