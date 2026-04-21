-- Check which trusted partners have logo_url values in businesses table
SELECT 
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id,
    b.logo_url,
    p.name as owner_name,
    p.email as owner_email
FROM businesses b
LEFT JOIN profiles p ON b.owner_member_id = p.id
WHERE b.owner_member_id IS NOT NULL
ORDER BY b.created_at DESC;

-- Check active deals and their associated logos
SELECT 
    tpd.id as deal_id,
    tpd.name as deal_name,
    tpd.trusted_partner_id,
    b.name as business_name,
    b.logo_url,
    tpd.is_active
FROM trusted_partner_discounts tpd
LEFT JOIN businesses b ON b.owner_member_id = tpd.trusted_partner_id
WHERE tpd.is_active = true
ORDER BY tpd.created_at DESC;
