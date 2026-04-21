-- Debug the latest authorization to see why it's not showing up correctly
-- Check all recent authorizations including the one just created

-- Get the most recent authorizations (last 10)
SELECT 
    id,
    member_id,
    business_id,
    discount_id,
    status,
    payment_method,
    amount,
    LEFT(notes, 50) as notes_preview,
    created_at,
    updated_at,
    approved_at,
    CASE 
        WHEN status = 'pending' THEN 'Should show in PENDING tab'
        WHEN status = 'approved' AND completed_at IS NULL THEN 'Should show in APPROVED tab (awaiting payment)'
        WHEN status = 'approved' AND completed_at IS NOT NULL THEN 'Should show in APPROVED tab (payment completed)'
        WHEN status = 'completed' THEN 'Should show in RECEIPTS tab'
        WHEN status = 'rejected' THEN 'Should NOT show (rejected)'
        ELSE 'Unknown status'
    END as expected_location
FROM deal_authorizations
ORDER BY created_at DESC
LIMIT 10;

-- Check if any are truly pending
SELECT 
    COUNT(*) as pending_count,
    'These should appear in Pending tab' as note
FROM deal_authorizations
WHERE status = 'pending';

-- Check if any are approved without payment
SELECT 
    COUNT(*) as approved_awaiting_payment_count,
    'These should appear in Approved tab with "Awaiting Payment" note' as note
FROM deal_authorizations
WHERE status = 'approved' AND payment_completed_at IS NULL;

-- Check if any are approved with payment completed
SELECT 
    COUNT(*) as approved_payment_complete_count,
    'These should appear in Approved tab marked as paid' as note
FROM deal_authorizations
WHERE status = 'approved' AND payment_completed_at IS NOT NULL;

-- Get the business info for the latest authorization
SELECT 
    da.id as auth_id,
    da.status,
    da.business_id,
    b.id as business_table_id,
    b.name as business_name,
    b.owner_member_id as business_owner_id,
    da.created_at
FROM deal_authorizations da
LEFT JOIN businesses b ON da.business_id = b.id
ORDER BY da.created_at DESC
LIMIT 5;

-- Check RLS: See if policies are blocking the view
-- This simulates what the app would see
SELECT 
    'Checking RLS policies...' as note;

-- Show which user owns which business
SELECT 
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id,
    COUNT(da.id) as authorization_count
FROM businesses b
LEFT JOIN deal_authorizations da ON da.business_id = b.id
GROUP BY b.id, b.name, b.owner_member_id
ORDER BY authorization_count DESC;
