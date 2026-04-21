-- =============================================================================
-- RENEWAL FLOW TESTING SCRIPT
-- =============================================================================
-- Use this script to test the subscription renewal flow
-- Run each section in Supabase SQL Editor and follow the instructions
-- =============================================================================

-- =============================================================================
-- STEP 1: IDENTIFY YOUR TEST USER
-- =============================================================================
-- Find your current logged-in user
-- Look at the app's console logs for: "Loading user data for user: [USER_ID]"
-- OR run this query to see recent users:

SELECT 
    id,
    email,
    created_at
FROM auth.users
ORDER BY created_at DESC
LIMIT 5;

-- Copy the user ID you want to test with:
-- YOUR_USER_ID = 'paste-here'

-- =============================================================================
-- STEP 2: CHECK CURRENT SUBSCRIPTION STATUS (Before Test)
-- =============================================================================
-- Replace YOUR_USER_ID with the actual UUID

SELECT 
    s.status as subscription_status,
    s.current_period_start,
    s.current_period_end,
    s.current_period_end < now() as is_expired,
    q.is_active as qr_active,
    q.expires_at as qr_expires
FROM subscriptions s
LEFT JOIN user_qr_codes q ON q.user_id = s.user_id AND q.is_active = true
WHERE s.user_id = 'YOUR_USER_ID'
ORDER BY s.created_at DESC
LIMIT 1;

-- Expected: 
-- subscription_status = 'active'
-- is_expired = false
-- qr_active = true

-- =============================================================================
-- STEP 3: EXPIRE THE SUBSCRIPTION (Trigger Test)
-- =============================================================================
-- This will expire the subscription to trigger the renewal popup
-- Replace YOUR_USER_ID with the actual UUID

UPDATE subscriptions 
SET current_period_end = '2025-01-01T00:00:00Z',
    status = 'active'  -- Keep as active initially, app will detect and change
WHERE user_id = 'YOUR_USER_ID';

-- Verify the update:
SELECT 
    status,
    current_period_end,
    current_period_end < now() as is_expired
FROM subscriptions 
WHERE user_id = 'YOUR_USER_ID';

-- Expected:
-- status = 'active' (will change to 'expired' when app detects it)
-- current_period_end = '2025-01-01 00:00:00+00'
-- is_expired = true

-- =============================================================================
-- STEP 4: RESTART APP OR HOT RELOAD
-- =============================================================================
-- In your terminal, run:
--   R  (hot reload)
-- OR
--   flutter run  (full restart - recommended)
--
-- Watch the console logs for:
-- ✅ "🔍 Checking subscription expiry"
-- ✅ "⏰ Subscription EXPIRED on 2025-01-01"
-- ✅ "🚫 QR codes deactivated"
-- ✅ "💬 Scheduling renewal popup display"
-- ✅ "🔔 Showing renewal popup"

-- =============================================================================
-- STEP 5: VERIFY EXPIRY DETECTION (Check Database Changes)
-- =============================================================================
-- After app restart, check that expiry was detected:

SELECT 
    s.status as subscription_status,
    s.current_period_end,
    q.is_active as qr_active,
    q.updated_at as qr_deactivated_at
FROM subscriptions s
LEFT JOIN user_qr_codes q ON q.user_id = s.user_id
WHERE s.user_id = 'YOUR_USER_ID'
ORDER BY s.updated_at DESC, q.updated_at DESC
LIMIT 1;

-- Expected after app detects expiry:
-- subscription_status = 'expired' (changed by app)
-- qr_active = false (deactivated by app)

-- =============================================================================
-- STEP 6: TEST RENEWAL POPUP
-- =============================================================================
-- The popup should appear automatically 500ms after app loads
-- 
-- Popup should show:
-- ✅ Warning icon (orange)
-- ✅ "Subscription Expired" title
-- ✅ Benefit list with checkmarks
-- ✅ Green pricing box: "R99.00 for 30 days"
-- ✅ Two buttons: "Not Now" (grey) and "Renew Subscription" (green)
--
-- TEST ACTION: Click "Not Now"
-- Expected: Popup closes, returns to Members Home Page
--
-- Then navigate back to trigger popup again, or restart app
--
-- TEST ACTION: Click "Renew Subscription"
-- Expected: Popup closes, navigates to Payment Options Screen

-- =============================================================================
-- STEP 7: COMPLETE TEST PAYMENT
-- =============================================================================
-- After clicking "Renew Subscription":
-- 1. Payment Options Screen should open
-- 2. Select payment method
-- 3. Complete payment on Paystack test page
-- 4. Click "Activate Subscription" button (manual trigger)
--
-- Watch console for:
-- ✅ "🔘 MANUAL ACTIVATE BUTTON PRESSED"
-- ✅ "[processManualPayment] Starting"
-- ✅ "[processManualPayment] Updating EXISTING subscription"
-- ✅ "[processManualPayment] SUCCESS"
-- ✅ "🚀 Auto-navigating to Members Home"

-- =============================================================================
-- STEP 8: VERIFY RENEWAL SUCCESS (Check Database)
-- =============================================================================
-- After payment completes, verify renewal:

SELECT 
    s.status,
    s.current_period_start,
    s.current_period_end,
    s.current_period_end > now() as is_active,
    EXTRACT(DAY FROM (s.current_period_end - now())) as days_remaining
FROM subscriptions s
WHERE s.user_id = 'YOUR_USER_ID'
ORDER BY s.updated_at DESC
LIMIT 1;

-- Expected:
-- status = 'active'
-- current_period_end = ~30 days from now
-- is_active = true
-- days_remaining = ~30

-- =============================================================================
-- STEP 9: VERIFY NEW QR CODE (Check Database)
-- =============================================================================
-- Check that a new QR code was generated:

SELECT 
    id,
    is_active,
    expires_at,
    created_at,
    EXTRACT(DAY FROM (expires_at - now())) as days_until_expiry
FROM user_qr_codes
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 3;

-- Expected:
-- Most recent QR code should have:
--   is_active = true
--   expires_at = ~30 days from now
--   days_until_expiry = ~30

-- =============================================================================
-- STEP 10: VERIFY UI STATE
-- =============================================================================
-- Check the app UI:
-- ✅ Members Home Page should be displayed
-- ✅ Active QR code should be visible
-- ✅ NO renewal popup (subscription is active)
-- ✅ Status card shows days remaining
-- ✅ QR code is scannable

-- =============================================================================
-- STEP 11: CHECK RENEWAL RECORD (Optional)
-- =============================================================================
-- Verify renewal was recorded:

SELECT 
    renewal_date,
    amount,
    status,
    qr_code_updated
FROM subscription_renewals
WHERE user_id = 'YOUR_USER_ID'
ORDER BY renewal_date DESC
LIMIT 3;

-- Expected:
-- Most recent record should show:
--   renewal_date = recent timestamp
--   amount = 99.00
--   status = 'success'
--   qr_code_updated = true

-- =============================================================================
-- STEP 12: RESET FOR REPEATED TESTING (Optional)
-- =============================================================================
-- If you want to test again, reset to active state:

UPDATE subscriptions 
SET status = 'active',
    current_period_end = NOW() + INTERVAL '30 days',
    current_period_start = NOW()
WHERE user_id = 'YOUR_USER_ID';

UPDATE user_qr_codes 
SET is_active = true,
    expires_at = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID'
  AND created_at = (
    SELECT MAX(created_at) 
    FROM user_qr_codes 
    WHERE user_id = 'YOUR_USER_ID'
  );

-- Verify reset:
SELECT 'Subscription reset to active state' as message;

-- =============================================================================
-- TROUBLESHOOTING
-- =============================================================================

-- Problem: Popup doesn't appear
-- Solution: Check these conditions

SELECT 
    s.status = 'expired' as status_is_expired,
    q.is_active = false as qr_is_inactive,
    s.current_period_end < now() as period_has_ended,
    CASE 
        WHEN s.status = 'expired' AND NOT q.is_active AND s.current_period_end < now() 
        THEN '✅ Popup should appear'
        ELSE '❌ Conditions not met for popup'
    END as popup_status
FROM subscriptions s
LEFT JOIN user_qr_codes q ON q.user_id = s.user_id
WHERE s.user_id = 'YOUR_USER_ID'
ORDER BY s.updated_at DESC, q.created_at DESC
LIMIT 1;

-- Problem: Payment succeeds but subscription not renewed
-- Check for errors in logs and verify this:

SELECT 
    'User ID' as field,
    user_id as value
FROM subscriptions 
WHERE user_id = 'YOUR_USER_ID'
UNION ALL
SELECT 
    'Profile subscription field',
    subscription
FROM profiles 
WHERE id = 'YOUR_USER_ID';

-- Both should show 'active' after successful payment

-- =============================================================================
-- CLEANUP (Only if needed)
-- =============================================================================
-- Emergency: Manually reactivate if something goes wrong

UPDATE subscriptions 
SET status = 'active',
    current_period_end = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID';

UPDATE user_qr_codes 
SET is_active = true,
    expires_at = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID'
  AND id = (SELECT id FROM user_qr_codes WHERE user_id = 'YOUR_USER_ID' ORDER BY created_at DESC LIMIT 1);

UPDATE profiles 
SET subscription = 'active'
WHERE id = 'YOUR_USER_ID';

SELECT 'Emergency reactivation complete' as status;

-- =============================================================================
-- END OF TESTING SCRIPT
-- =============================================================================
