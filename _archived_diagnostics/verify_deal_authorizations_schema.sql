-- Verification script for deal_authorizations table schema
-- Run this to check if the database is correctly configured

-- 1. Check all columns in deal_authorizations table
SELECT 
    column_name, 
    data_type, 
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- 2. Check all foreign key constraints on deal_authorizations
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
LEFT JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'deal_authorizations'
ORDER BY tc.constraint_name;

-- 3. Check if there are any invalid foreign key references
-- This will show any deal_authorizations with invalid business_id
SELECT 
    da.id,
    da.business_id,
    da.trusted_partner_id,
    da.member_id,
    da.discount_id,
    b.id as business_exists,
    CASE 
        WHEN b.id IS NULL THEN '❌ Invalid business_id'
        ELSE '✅ Valid business_id'
    END as business_status
FROM deal_authorizations da
LEFT JOIN businesses b ON da.business_id = b.id
WHERE da.business_id IS NOT NULL
LIMIT 10;

-- 4. Check if there are any deal_authorizations with invalid trusted_partner_id
SELECT 
    da.id,
    da.trusted_partner_id,
    b.id as business_exists,
    CASE 
        WHEN da.trusted_partner_id IS NULL THEN '⚠️ NULL trusted_partner_id'
        WHEN b.id IS NULL THEN '❌ Invalid trusted_partner_id (not in businesses table)'
        ELSE '✅ Valid trusted_partner_id'
    END as tp_status
FROM deal_authorizations da
LEFT JOIN businesses b ON da.trusted_partner_id = b.id
WHERE da.trusted_partner_id IS NOT NULL
LIMIT 10;

-- 5. Check for deal_authorizations where trusted_partner_id looks like a user ID (not business ID)
-- User IDs from profiles vs Business IDs from businesses
SELECT 
    da.id,
    da.trusted_partner_id,
    da.business_id,
    CASE 
        WHEN p.id IS NOT NULL THEN '❌ PROBLEM: trusted_partner_id is a USER ID (should be business ID)'
        WHEN b.id IS NOT NULL THEN '✅ OK: trusted_partner_id is a business ID'
        ELSE '⚠️ Unknown: ID not found in either table'
    END as analysis
FROM deal_authorizations da
LEFT JOIN profiles p ON da.trusted_partner_id = p.id
LEFT JOIN businesses b ON da.trusted_partner_id = b.id
WHERE da.trusted_partner_id IS NOT NULL;

-- 6. Summary of issues
SELECT 
    COUNT(*) FILTER (WHERE trusted_partner_id IS NULL) as null_trusted_partner_id,
    COUNT(*) FILTER (WHERE business_id IS NULL) as null_business_id,
    COUNT(*) as total_authorizations
FROM deal_authorizations;
