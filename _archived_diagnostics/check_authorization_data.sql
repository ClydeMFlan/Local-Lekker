-- Check what data is actually stored in deal_authorizations for clydemflan@gmail.com
WITH user_info AS (
  SELECT id as user_id
  FROM profiles
  WHERE email = 'clydemflan@gmail.com'
)
SELECT 
    da.id,
    da.created_at,
    da.amount,
    da.notes,  -- This might contain quantity info!
    da.bill_data,
    da.status,
    
    -- Join to see what discount it was
    dr.discount_name,
    tpd.is_bill_discount,
    tpd.is_weight_based,
    tpd.percentage,
    tpd.fixed_amount,
    tpd.item_price,
    
    -- Join to see the receipt
    dr.receipt_number,
    dr.business_name
FROM deal_authorizations da
LEFT JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
LEFT JOIN deal_receipts dr ON dr.deal_authorization_id = da.id
WHERE da.member_id = (SELECT user_id FROM user_info)
ORDER BY da.created_at DESC;

-- Check the structure of notes field - is it JSON or plain text?
WITH user_info AS (
  SELECT id as user_id
  FROM profiles
  WHERE email = 'clydemflan@gmail.com'
)
SELECT 
    id,
    notes,
    -- Try to parse as JSON
    CASE 
        WHEN notes::text LIKE '{%}' THEN 'Looks like JSON'
        ELSE 'Plain text or NULL'
    END as notes_format,
    LENGTH(notes::text) as notes_length
FROM deal_authorizations
WHERE member_id = (SELECT user_id FROM user_info)
AND notes IS NOT NULL;
