-- Check the actual bill_data stored for the latest receipt
-- This will show if tip_amount is stored correctly as 166.50

SELECT 
    da.id,
    da.member_id,
    da.amount,
    da.bill_data,
    da.bill_data->>'tip_amount' as extracted_tip,
    da.bill_data->>'original_bill_amount' as original_amount,
    da.bill_data->>'discount_amount' as discount_amount,
    da.bill_data->>'excluded_items_total' as excluded_items,
    da.bill_data->>'final_amount' as final_amount,
    da.created_at
FROM deal_authorizations da
WHERE da.bill_data IS NOT NULL
ORDER BY da.created_at DESC
LIMIT 5;

-- Also check if there are multiple authorizations for the same receipt
SELECT 
    dr.receipt_number,
    dr.member_id,
    COUNT(vr.id) as num_virtual_receipts,
    COUNT(da.id) as num_authorizations,
    SUM((da.bill_data->>'tip_amount')::numeric) as total_tips_in_bill_data
FROM deal_receipts dr
LEFT JOIN virtual_receipts vr ON vr.deal_authorization_id = dr.deal_authorization_id
LEFT JOIN deal_authorizations da ON da.id = vr.deal_authorization_id
WHERE dr.member_id = (
    SELECT id FROM profiles 
    WHERE email = 'clydemfaln@gmail.com'
    LIMIT 1
)
GROUP BY dr.receipt_number, dr.member_id;
