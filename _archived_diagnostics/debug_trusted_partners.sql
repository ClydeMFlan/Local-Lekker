-- Check all records in trusted_partners table
SELECT
    user_id,
    business_name,
    paystack_recipient_code,
    paystack_subaccount_id,
    created_at,
    updated_at
FROM trusted_partners
ORDER BY updated_at DESC NULLS LAST;

-- Count total records
SELECT COUNT(*) as total_trusted_partners FROM trusted_partners;

-- Check if paystack_recipient_code column exists and has data
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partners'
AND column_name = 'paystack_recipient_code';