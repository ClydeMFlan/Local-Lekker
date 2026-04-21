-- =============================================================================
-- CHECK TABLE SCHEMAS FIRST
-- =============================================================================

-- Check trusted_partner_discounts table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'trusted_partner_discounts'
ORDER BY ordinal_position;

-- Check businesses table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'businesses'
ORDER BY ordinal_position;

-- Check deal_authorizations table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
ORDER BY ordinal_position;

-- Check notifications table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'notifications'
ORDER BY ordinal_position;

-- =============================================================================
-- 1. SETUP TEST DATA
-- =============================================================================
-- Create test users and business (run these manually in Supabase)
-- Note: Replace these UUIDs with actual user IDs from your auth.users table

-- Test Member User ID: '32048961-7f36-4720-83af-d76929ba73d9' (jasoncoetzer@gmail.com)
-- Test Trusted Partner User ID: '15e512c6-73d4-4d0b-9696-447fec288482' (houselillian5@gmail.com)

-- Create test business for trusted partner
-- NOTE: Using existing business "Momsies" owned by houselillian5@gmail.com
-- Business ID: 4cd2fb8e-7971-4336-92a6-71670c689905

-- Create test discount for the business
INSERT INTO trusted_partner_discounts (
    id, trusted_partner_id, business_id, name, description,
    item_name, item_price, percentage, is_active, created_at, updated_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440002',
    '15e512c6-73d4-4d0b-9696-447fec288482', -- trusted partner user id
    '4cd2fb8e-7971-4336-92a6-71670c689905', -- existing business id (Momsies)
    'Test Discount',
    'A test discount for deal authorization',
    'Test Item',
    100.00,
    20.0,
    true,
    NOW(),
    NOW()
) ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- 2. TEST RLS POLICIES INDIVIDUALLY
-- =============================================================================

-- Test 1: Member can view discounts (should work for anyone now)
SELECT 'Test 1: Anyone can view discounts' as test_name;
SELECT COUNT(*) as visible_discounts FROM trusted_partner_discounts;

-- Test 2: Member can view businesses (should work)
SELECT 'Test 2: Users can view businesses' as test_name;
SELECT COUNT(*) as visible_businesses FROM businesses;

-- Test 3: Member can view their own deal authorizations (should return 0 initially)
SELECT 'Test 3: Member can view their own authorizations' as test_name;
SELECT COUNT(*) as member_authorizations
FROM deal_authorizations
WHERE member_id = '32048961-7f36-4720-83af-d76929ba73d9';

-- Test 4: Trusted partner can view authorizations for their business (should return 0 initially)
SELECT 'Test 4: Trusted partner can view business authorizations' as test_name;
SELECT COUNT(*) as business_authorizations
FROM deal_authorizations
WHERE trusted_partner_id = '4cd2fb8e-7971-4336-92a6-71670c689905';

-- Test 5: Member can view their own notifications (should return 0 initially)
SELECT 'Test 5: Member can view their notifications' as test_name;
SELECT COUNT(*) as member_notifications
FROM notifications
WHERE user_id = '32048961-7f36-4720-83af-d76929ba73d9';

-- =============================================================================
-- 3. SIMULATE DEAL AUTHORIZATION REQUEST (what the app does)
-- =============================================================================

-- Step 1: Member requests deal authorization (INSERT into deal_authorizations)
SELECT 'Step 1: Member requests deal authorization' as test_name;
INSERT INTO deal_authorizations (
    id, member_id, trusted_partner_id, discount_id, status,
    notes, created_at, updated_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440003',
    '32048961-7f36-4720-83af-d76929ba73d9', -- member user id
    '4cd2fb8e-7971-4336-92a6-71670c689905', -- existing business id (Momsies)
    '550e8400-e29b-41d4-a716-446655440002', -- discount id
    'pending',
    'Test deal authorization request',
    NOW(),
    NOW()
);

-- Step 2: Create notification for trusted partner (INSERT into notifications)
SELECT 'Step 2: Create notification for trusted partner' as test_name;
INSERT INTO notifications (
    id, user_id, type, title, message, data, is_read,
    created_at, updated_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440004',
    '15e512c6-73d4-4d0b-9696-447fec288482', -- trusted partner user id
    'deal_authorization_request',
    'New Deal Authorization Request',
    'A member has requested authorization for your discount: Test Discount',
    '{"discount_id": "550e8400-e29b-41d4-a716-446655440002", "authorization_id": "550e8400-e29b-41d4-a716-446655440003"}',
    false,
    NOW(),
    NOW()
);

-- =============================================================================
-- 4. VERIFY THE FLOW WORKED
-- =============================================================================

-- Check that authorization was created
SELECT 'Verification 1: Authorization created' as test_name;
SELECT id, member_id, trusted_partner_id, status, notes
FROM deal_authorizations
WHERE id = '550e8400-e29b-41d4-a716-446655440003';

-- Check that notification was created
SELECT 'Verification 2: Notification created' as test_name;
SELECT id, user_id, type, title, is_read
FROM notifications
WHERE id = '550e8400-e29b-41d4-a716-446655440004';

-- Check that member can see their authorization
SELECT 'Verification 3: Member can see their authorization' as test_name;
SELECT COUNT(*) as member_can_see_auth
FROM deal_authorizations
WHERE member_id = '32048961-7f36-4720-83af-d76929ba73d9'
  AND id = '550e8400-e29b-41d4-a716-446655440003';

-- Check that trusted partner can see the authorization for their business
SELECT 'Verification 4: Trusted partner can see business authorization' as test_name;
SELECT COUNT(*) as partner_can_see_auth
FROM deal_authorizations
WHERE trusted_partner_id = '4cd2fb8e-7971-4336-92a6-71670c689905'
  AND id = '550e8400-e29b-41d4-a716-446655440003';

-- Check that trusted partner can see their notification
SELECT 'Verification 5: Trusted partner can see their notification' as test_name;
SELECT COUNT(*) as partner_can_see_notification
FROM notifications
WHERE user_id = '15e512c6-73d4-4d0b-9696-447fec288482'
  AND id = '550e8400-e29b-41d4-a716-446655440004';

-- =============================================================================
-- 5. TEST TRUSTED PARTNER RESPONSE (UPDATE authorization)
-- =============================================================================

SELECT 'Step 3: Trusted partner updates authorization status' as test_name;
UPDATE deal_authorizations
SET status = 'approved',
    notes = 'Approved! Welcome to our discount program.',
    updated_at = NOW()
WHERE id = '550e8400-e29b-41d4-a716-446655440003'
  AND trusted_partner_id = '4cd2fb8e-7971-4336-92a6-71670c689905';

-- Verify the update worked
SELECT 'Verification 6: Authorization status updated' as test_name;
SELECT id, status, notes
FROM deal_authorizations
WHERE id = '550e8400-e29b-41d4-a716-446655440003';

-- =============================================================================
-- 6. CLEANUP TEST DATA
-- =============================================================================
-- Uncomment these lines to clean up after testing
-- NOTE: Not deleting the business since we're using the existing "Momsies" business
/*
DELETE FROM notifications WHERE id = '550e8400-e29b-41d4-a716-446655440004';
DELETE FROM deal_authorizations WHERE id = '550e8400-e29b-41d4-a716-446655440003';
DELETE FROM trusted_partner_discounts WHERE id = '550e8400-e29b-41d4-a716-446655440002';
-- DELETE FROM businesses WHERE id = '4cd2fb8e-7971-4336-92a6-71670c689905'; -- Don't delete existing business
*/

-- =============================================================================
-- FINAL STATUS REPORT
-- =============================================================================
SELECT 'FINAL TEST RESULTS' as report;
SELECT
    'Total businesses' as metric,
    COUNT(*) as count
FROM businesses
UNION ALL
SELECT
    'Total discounts' as metric,
    COUNT(*) as count
FROM trusted_partner_discounts
UNION ALL
SELECT
    'Total authorizations' as metric,
    COUNT(*) as count
FROM deal_authorizations
UNION ALL
SELECT
    'Total notifications' as metric,
    COUNT(*) as count
FROM notifications;