-- Debug script to find the business_id mismatch issue
-- Run this to identify the problematic data

-- 1. Check if the deal exists and what business_id it has
SELECT 
    tpd.id as discount_id,
    tpd.name as deal_name,
    tpd.business_id,
    tpd.trusted_partner_id,
    b.id as actual_business_id,
    b.name as business_name,
    CASE 
        WHEN b.id IS NULL THEN '❌ MISSING BUSINESS'
        WHEN tpd.business_id != b.id THEN '⚠️ ID MISMATCH'
        ELSE '✅ OK'
    END as status
FROM trusted_partner_discounts tpd
LEFT JOIN businesses b ON b.owner_member_id = tpd.trusted_partner_id
WHERE tpd.name LIKE '%Grass-fed%' OR tpd.name LIKE '%steak%'
ORDER BY tpd.created_at DESC;

-- 2. Check all discounts with missing or invalid business_id
SELECT 
    tpd.id as discount_id,
    tpd.name as deal_name,
    tpd.business_id as stored_business_id,
    tpd.trusted_partner_id,
    p.email as partner_email,
    b.id as correct_business_id,
    b.name as business_name
FROM trusted_partner_discounts tpd
LEFT JOIN profiles p ON p.id = tpd.trusted_partner_id
LEFT JOIN businesses b ON b.id = tpd.business_id
WHERE tpd.business_id IS NOT NULL 
  AND b.id IS NULL  -- business_id points to non-existent business
ORDER BY tpd.created_at DESC;

-- 3. Find the correct business_id for each trusted partner
SELECT 
    tpd.id as discount_id,
    tpd.name as deal_name,
    tpd.business_id as wrong_business_id,
    tpd.trusted_partner_id,
    b.id as correct_business_id,
    b.name as business_name
FROM trusted_partner_discounts tpd
LEFT JOIN businesses b ON b.owner_member_id = tpd.trusted_partner_id
WHERE tpd.business_id IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM businesses WHERE id = tpd.business_id
  )
ORDER BY tpd.created_at DESC;

-- 4. Check for trusted partners without businesses
SELECT 
    p.id as trusted_partner_id,
    p.email,
    p.name,
    COUNT(tpd.id) as discount_count,
    CASE 
        WHEN b.id IS NULL THEN '❌ NO BUSINESS'
        ELSE '✅ HAS BUSINESS'
    END as business_status
FROM profiles p
LEFT JOIN trusted_partner_discounts tpd ON tpd.trusted_partner_id = p.id
LEFT JOIN businesses b ON b.owner_member_id = p.id
WHERE p.role = 'trusted_partner'
GROUP BY p.id, p.email, p.name, b.id;
