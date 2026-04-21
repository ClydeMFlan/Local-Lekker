# Subscription Renewal Flow - Testing Guide

## 🎯 Feature: Renewal Popup on Subscription Expiry

### What's Been Implemented

#### 1. Renewal Popup Dialog ✅
**Location:** `lib/features/auth/members_home_page.dart`

**Features:**
- 🎨 Beautiful modal dialog with warning icon
- 📋 Clear messaging about expired subscription
- ✓ List of benefits for renewing
- 💰 Price display (R99.00 for 30 days)
- 🔘 Two action buttons: "Not Now" and "Renew Subscription"
- 🚫 Non-dismissible (user must choose an action)

**Trigger Conditions:**
```dart
if (wasExpired && !hasActiveQr && subscriptionStatus == 'expired') {
  _showRenewalPopup();
}
```

#### 2. Auto-Display Logic ✅
- Checks for expiry on app load
- Shows popup 500ms after UI loads (ensures context is ready)
- Only shows once per session (when expiry is first detected)

---

## 🧪 Testing Instructions

### Test Case 1: Expired Subscription Flow

**Setup:**
1. Log in with a user who has an active subscription
2. Note the user ID
3. Open Supabase SQL Editor

**Step 1: Expire the Subscription**
Run this SQL to manually expire a subscription:
```sql
-- Replace YOUR_USER_ID with actual UUID
UPDATE subscriptions 
SET current_period_end = '2025-01-01T00:00:00Z',
    status = 'active'  -- Keep as active initially
WHERE user_id = 'YOUR_USER_ID';
```

**Step 2: Trigger Expiry Detection**
Option A - Restart App:
```bash
# In terminal
R  # Hot reload (may not work for expiry check)
# OR
flutter run  # Full restart (recommended)
```

Option B - Resume from Background:
1. Send app to background (home button)
2. Wait 2 seconds
3. Bring app back to foreground
4. App lifecycle check should trigger

**Expected Results:**

**✅ Console Logs (in order):**
```
🔄 Loading user data for user: [user-id]
🔍 Checking subscription expiry for user: [user-id]
⏰ Subscription EXPIRED on 2025-01-01T00:00:00.000Z
📅 Current time: 2025-10-16T...
🚫 QR codes deactivated for expired subscription
📝 Subscription status updated to expired
🚨 Subscription was expired - QR codes deactivated
📊 Subscription status result: {
  ...
  has_active_qr: false,
  subscription_status: expired
}
💬 Scheduling renewal popup display
🔔 Showing renewal popup for expired subscription
```

**✅ Visual Results:**
1. **500ms after load** - Renewal popup appears
2. **Popup contains:**
   - ⚠️ Orange warning icon + "Subscription Expired" title
   - "Your subscription has expired..." message
   - Benefits list with checkmarks
   - Green pricing box: "R99.00 for 30 days"
   - "Not Now" button (grey)
   - "Renew Subscription" button (green)

**✅ Database Changes:**
```sql
-- Verify in Supabase
SELECT status FROM subscriptions WHERE user_id = 'YOUR_USER_ID';
-- Should show: expired

SELECT is_active FROM user_qr_codes WHERE user_id = 'YOUR_USER_ID';
-- Should show: false (all QR codes deactivated)
```

---

### Test Case 2: User Clicks "Renew Subscription"

**Prerequisites:** Complete Test Case 1

**Action:**
Click the green "Renew Subscription" button in the popup

**Expected Results:**

**✅ Console Logs:**
```
✅ User clicked Renew Subscription
🚀 Navigating to payment screen...
📊 Current subscription data: {...}
```

**✅ Navigation:**
- Popup closes
- Navigates to `PaymentOptionsScreen`
- Shows payment plan selection

**✅ Payment Options Screen:**
- Should display "Renewal" plan type
- Price: R99.00
- Duration: 30 days

---

### Test Case 3: User Clicks "Not Now"

**Prerequisites:** Complete Test Case 1

**Action:**
Click the grey "Not Now" button in the popup

**Expected Results:**

**✅ Console Logs:**
```
❌ User dismissed renewal popup
```

**✅ Behavior:**
- Popup closes
- Returns to Members Home Page
- Shows "Subscription expired" card with inline "Renew Subscription" button
- No QR code displayed

---

### Test Case 4: Successful Renewal Payment

**Prerequisites:** Complete Test Case 2, proceed with payment

**Action:**
1. Complete payment on Paystack test page
2. Click "Activate Subscription" button (if auto-detection fails)

**Expected Results:**

**✅ Console Logs:**
```
🔘 MANUAL ACTIVATE BUTTON PRESSED
✅ Payment success handler called
[processManualPayment] Starting...
[processManualPayment] Deactivated ALL QR codes
[processManualPayment] New QR code: {...}
[processManualPayment] Creating NEW subscription record...
[processManualPayment] SUCCESS
🚀 Auto-navigating to Members Home
```

**✅ Database Updates:**
```sql
-- New subscription period
SELECT 
    status,
    current_period_start,
    current_period_end
FROM subscriptions 
WHERE user_id = 'YOUR_USER_ID';
-- Should show:
--   status: active
--   current_period_end: ~30 days from now

-- New active QR code
SELECT 
    is_active,
    expires_at
FROM user_qr_codes 
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 1;
-- Should show:
--   is_active: true
--   expires_at: ~30 days from now
```

**✅ UI State:**
- Navigates to Members Home Page
- Shows active QR code
- No renewal popup (subscription is active)
- Status card shows days remaining

---

## 🐛 Troubleshooting

### Issue: Popup doesn't appear

**Possible Causes:**
1. Subscription not actually expired
   - Check: `current_period_end > now`
2. QR code still active
   - Check: `is_active = true` in database
3. Status not set to 'expired'
   - Check: `status != 'expired'` in subscriptions table

**Solution:**
Run this to force expired state:
```sql
UPDATE subscriptions 
SET status = 'expired',
    current_period_end = '2025-01-01T00:00:00Z'
WHERE user_id = 'YOUR_USER_ID';

UPDATE user_qr_codes 
SET is_active = false
WHERE user_id = 'YOUR_USER_ID';
```

Then restart app.

---

### Issue: Popup appears but navigation fails

**Possible Causes:**
1. PaymentOptionsScreen not properly configured
2. Navigation context issues

**Debug:**
Check console for navigation errors. Ensure `_navigateToPaymentScreen()` method exists and works.

---

### Issue: Payment succeeds but QR not reactivated

**Possible Causes:**
1. processManualPayment() failed
2. RLS policy blocking updates

**Debug:**
1. Check logs for `[processManualPayment] ERROR`
2. Verify RLS policies allow user updates
3. Check database directly for updates

**Manual Fix:**
```sql
-- Manually reactivate if needed
UPDATE subscriptions 
SET status = 'active',
    current_period_end = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID';

-- Generate new QR code manually
INSERT INTO user_qr_codes (user_id, qr_code, is_active, expires_at)
VALUES (
  'YOUR_USER_ID',
  '{"user_id": "YOUR_USER_ID", "timestamp": extract(epoch from now())}'::jsonb,
  true,
  NOW() + INTERVAL '30 days'
);
```

---

## 📋 Testing Checklist

Use this checklist for comprehensive testing:

### Pre-Test Setup
- [ ] Active subscription exists
- [ ] User can log in successfully
- [ ] Members Home Page loads correctly

### Expiry Detection
- [ ] SQL script runs without errors
- [ ] App restart triggers expiry check
- [ ] Console shows "⏰ Subscription EXPIRED" log
- [ ] QR codes deactivated in database
- [ ] Subscription status set to 'expired'

### Popup Display
- [ ] Popup appears 500ms after load
- [ ] Warning icon displayed (orange)
- [ ] Title: "Subscription Expired"
- [ ] Benefits list shows 3 items
- [ ] Price box shows "R99.00 for 30 days"
- [ ] Two buttons: "Not Now" and "Renew Subscription"
- [ ] Popup cannot be dismissed by tapping outside

### User Interactions
- [ ] "Not Now" button closes popup
- [ ] Returns to Members Home with inline renewal button
- [ ] "Renew Subscription" closes popup
- [ ] Navigates to PaymentOptionsScreen
- [ ] Payment screen shows correct renewal info

### Payment Flow
- [ ] Can complete test payment on Paystack
- [ ] Success detection works (auto or manual)
- [ ] processManualPayment() executes successfully
- [ ] Database updated with new subscription period
- [ ] New QR code generated and activated
- [ ] Navigates back to Members Home
- [ ] Active QR code displayed
- [ ] No renewal popup on subsequent loads

---

## 📊 Success Criteria

All tests pass when:
- ✅ Expired subscriptions are detected automatically
- ✅ Renewal popup appears at the right time
- ✅ User can dismiss or proceed with renewal
- ✅ Payment flow completes successfully
- ✅ Subscription is reactivated with new 30-day period
- ✅ New QR code is generated and active
- ✅ UI reflects updated subscription state

---

## 🔄 Reset Test Environment

To reset for repeated testing:

```sql
-- Reset subscription to active state
UPDATE subscriptions 
SET status = 'active',
    current_period_end = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID';

-- Reactivate QR code
UPDATE user_qr_codes 
SET is_active = true,
    expires_at = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID'
  AND created_at = (
    SELECT MAX(created_at) 
    FROM user_qr_codes 
    WHERE user_id = 'YOUR_USER_ID'
  );
```

---

**Test Date:** October 16, 2025  
**Version:** v1.0 - Initial Implementation  
**Status:** ✅ Ready for Testing
