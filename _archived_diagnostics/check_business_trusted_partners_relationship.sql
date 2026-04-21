-- Check the relationship between businesses and trusted_partners
-- This will help us understand why retrieval might be failing

-- 1. Show all businesses with their owners
SELECT
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id as business_owner_id,
    p.email as owner_email
FROM businesses b
LEFT JOIN profiles p ON b.owner_member_id = p.id
ORDER BY b.created_at DESC;

-- 2. Show all trusted_partners records with business context
SELECT
    tp.user_id as trusted_partner_user_id,
    tp.paystack_recipient_code,
    tp.paystack_subaccount_id,
    tp.business_name,
    tp.created_at,
    tp.updated_at,
    -- Check if this user_id matches any business owner
    CASE
        WHEN EXISTS (SELECT 1 FROM businesses b WHERE b.owner_member_id = tp.user_id) THEN 'Has Business'
        ELSE 'No Business Found'
    END as business_relationship,
    -- Get business details if they exist
    (SELECT json_build_object('id', b.id, 'name', b.name)
     FROM businesses b
     WHERE b.owner_member_id = tp.user_id
     LIMIT 1) as associated_business
FROM trusted_partners tp
ORDER BY tp.updated_at DESC;

-- 3. Check if the trusted_partners user_id exists in profiles
SELECT
    tp.user_id,
    tp.paystack_recipient_code,
    CASE
        WHEN p.id IS NOT NULL THEN 'Profile Exists'
        ELSE 'Profile Missing'
    END as profile_status,
    p.email,
    p.role
FROM trusted_partners tp
LEFT JOIN profiles p ON tp.user_id = p.id;

-- 4. Cross-reference: For each business, check if trusted_partners record exists
SELECT
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id as owner_user_id,
    CASE
        WHEN tp.user_id IS NOT NULL THEN 'Has Trusted Partner Record'
        ELSE 'No Trusted Partner Record'
    END as trusted_partner_status,
    tp.paystack_recipient_code,
    tp.paystack_subaccount_id
FROM businesses b
LEFT JOIN trusted_partners tp ON b.owner_member_id = tp.user_id
ORDER BY b.created_at DESC;