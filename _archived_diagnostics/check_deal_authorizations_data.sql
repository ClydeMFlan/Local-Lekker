-- Check what data exists in deal_authorizations table

-- 1. Count of deals by status
SELECT 
    status,
    COUNT(*) as count,
    SUM(amount) as total_amount
FROM deal_authorizations
GROUP BY status
ORDER BY count DESC;

-- 2. Check if business_id exists and is populated
SELECT 
    COUNT(*) as total_deals,
    COUNT(business_id) as deals_with_business_id,
    COUNT(amount) as deals_with_amount,
    COUNT(payment_method) as deals_with_payment_method
FROM deal_authorizations;

-- 3. Sample of actual deal data
SELECT 
    id,
    business_id,
    member_id,
    status,
    amount,
    payment_method,
    created_at
FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check businesses table
SELECT 
    id,
    name,
    created_at
FROM businesses
LIMIT 10;

-- 5. Join check - see if deals connect to businesses
SELECT 
    da.id,
    da.status,
    da.amount,
    da.payment_method,
    b.name as business_name,
    b.id as business_id
FROM deal_authorizations da
LEFT JOIN businesses b ON da.business_id = b.id
ORDER BY da.created_at DESC
LIMIT 10;

-- 6. Count deals per business
SELECT 
    b.name as business_name,
    b.id as business_id,
    COUNT(da.id) as deal_count,
    SUM(CASE WHEN da.status = 'completed' THEN da.amount ELSE 0 END) as completed_revenue,
    SUM(da.amount) as total_amount
FROM businesses b
LEFT JOIN deal_authorizations da ON b.id = da.business_id
GROUP BY b.id, b.name
ORDER BY deal_count DESC;
