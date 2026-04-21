-- Check if the recipient code was saved in Supabase
SELECT
    user_id,
    paystack_recipient_code,
    created_at,
    updated_at
FROM trusted_partners
WHERE paystack_recipient_code IS NOT NULL
ORDER BY updated_at DESC;