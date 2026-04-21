-- Check weight-based deal data in deal_receipts and deal_authorizations
SELECT
    dr.id as receipt_id,
    dr.amount as receipt_amount,
    dr.member_id,
    da.id as auth_id,
    da.amount as auth_amount,
    da.quantity,
    da.discount_id,
    da.bill_data,
    tpd.product_name,
    tpd.is_weight_based,
    tpd.is_bill_discount,
    tpd.item_price,
    tpd.fixed_amount,
    tpd.percentage
FROM deal_receipts dr
JOIN deal_authorizations da ON dr.deal_authorization_id = da.id
JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
WHERE dr.member_id = '6c815ef9-5e8a-498b-927c-9d807421f791'
AND tpd.is_weight_based = true
ORDER BY dr.created_at DESC;