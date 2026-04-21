-- Check current database state for banking details debugging
-- This query helps us understand what data exists in the trusted_partners and businesses tables

-- Check trusted_partners table structure and data
SELECT
    'trusted_partners table info:' as info,
    COUNT(*) as total_records,
    COUNT(paystack_recipient_code) as records_with_recipient_code,
    COUNT(CASE WHEN paystack_recipient_code IS NOT NULL AND paystack_recipient_code != '' THEN 1 END) as non_empty_recipient_codes
FROM trusted_partners;

-- Show all trusted_partners records (limited for safety)
SELECT
    user_id,
    business_name,
    paystack_recipient_code,
    created_at,
    updated_at
FROM trusted_partners
ORDER BY created_at DESC
LIMIT 10;

-- Check businesses table
SELECT
    'businesses table info:' as info,
    COUNT(*) as total_businesses,
    COUNT(owner_member_id) as businesses_with_owners
FROM businesses;

-- Show recent businesses
SELECT
    id,
    owner_member_id,
    name,
    created_at
FROM businesses
ORDER BY created_at DESC
LIMIT 5;

-- Check if there are any users with profiles
SELECT
    'profiles table info:' as info,
    COUNT(*) as total_profiles,
    COUNT(role) as profiles_with_roles
FROM profiles;

-- Show recent profiles
SELECT
    id,
    email,
    role,
    created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 5;