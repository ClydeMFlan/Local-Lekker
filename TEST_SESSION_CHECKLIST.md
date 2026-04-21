# 🧪 LIVE TESTING SESSION - Subscription Renewal Flow

## Test Date: October 16, 2025
## Tester: [Your Name]
## Session Start: [Time]

---

## 📋 Pre-Test Checklist

Before we begin, ensure:
- [x] App is running on device
- [ ] You're logged in as a test user
- [ ] You know your user ID
- [ ] Supabase SQL Editor is open
- [ ] You have test payment credentials

---

## 🎯 TEST 1: Expire Subscription

### Step 1: Get Your User ID
1. Look at the app logs when you're on Members Home Page
2. Find the line: `🔄 Loading user data for user: [USER-ID]`
3. **Your User ID:** `_____________________________________`

### Step 2: Expire the Subscription in Database
Open Supabase SQL Editor and run:

```sql
-- Replace YOUR_USER_ID with actual UUID from Step 1
UPDATE subscriptions 
SET current_period_end = '2025-01-01T00:00:00Z',
    status = 'active'  -- Keep as active initially to test detection
WHERE user_id = 'YOUR_USER_ID';
```

**Query Result:**
- [ ] ✅ Query executed successfully
- [ ] ❌ Error: _______________________

### Step 3: Restart the App
In the terminal where Flutter is running, type: `R` (capital R for full restart)

**Expected Console Output:**
```
🔄 Loading user data for user: [user-id]
🔍 Checking subscription expiry for user: [user-id]
⏰ Subscription EXPIRED on 2025-01-01T00:00:00.000Z
📅 Current time: [current-time]
🚫 QR codes deactivated for expired subscription
📝 Subscription status updated to expired
🚨 Subscription was expired - QR codes deactivated
```

**Actual Console Output:**
```
[Paste relevant logs here]
```

**Result:**
- [ ] ✅ Expiry detected correctly
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 2: Renewal Popup Display

### Expected Behavior (500ms after app loads):

**Visual Checklist:**
- [ ] Popup appears automatically
- [ ] Orange warning icon displayed
- [ ] Title: "Subscription Expired"
- [ ] Body text: "Your subscription has expired..."
- [ ] Benefits list with 3 items:
  - [ ] "✓ Reactivate your QR code"
  - [ ] "✓ Continue receiving instant discounts"
  - [ ] "✓ Access exclusive local deals"
- [ ] Green pricing box: "R99.00 for 30 days"
- [ ] Two buttons visible:
  - [ ] "Not Now" (grey)
  - [ ] "Renew Subscription" (green)
- [ ] Cannot dismiss by tapping outside

**Console Output:**
```
💬 Scheduling renewal popup display
🔔 Showing renewal popup for expired subscription
```

**Screenshot/Photo:** [Take a photo of the popup]

**Result:**
- [ ] ✅ Popup displays correctly
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 3A: User Clicks "Not Now"

### Action:
Click the grey "Not Now" button

### Expected Behavior:

**Console Output:**
```
❌ User dismissed renewal popup
```

**Visual Result:**
- [ ] Popup closes
- [ ] Returns to Members Home Page
- [ ] Shows "Subscription expired" card
- [ ] Inline "Renew Subscription" button visible
- [ ] No QR code displayed

**Actual Result:**
- [ ] ✅ Behavior matches expected
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 3B: User Clicks "Renew Subscription"

### Setup:
Restart the app (type `R`) to see the popup again

### Action:
Click the green "Renew Subscription" button

### Expected Behavior:

**Console Output:**
```
✅ User clicked Renew Subscription
🚀 Navigating to payment screen...
📊 Current subscription data: {...}
```

**Navigation:**
- [ ] Popup closes immediately
- [ ] Navigates to PaymentOptionsScreen
- [ ] Screen title: "Payment Options" or similar
- [ ] Shows "Renewal" plan type
- [ ] Shows price: R99.00
- [ ] Shows duration: 30 days

**Screenshot:** [Take a photo of payment options screen]

**Result:**
- [ ] ✅ Navigation works correctly
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 4: Complete Renewal Payment

### Step 1: Initiate Payment
On PaymentOptionsScreen, select payment method and proceed

### Step 2: Complete Test Payment
On Paystack test page:
- Use test card: `4084084084084081`
- Expiry: Any future date
- CVV: `408`
- OTP: `123456`

### Step 3: Manual Activation (if needed)
If payment succeeds but app stays on Paystack page:
- [ ] Blue "Activate Subscription" button visible at bottom
- [ ] Click the button

### Expected Console Output:
```
🔘 MANUAL ACTIVATE BUTTON PRESSED
✅ PAYMENT SUCCESS HANDLER CALLED
✅ Activate overlay forced visible after payment success.
✅ Processing payment for userId: [user-id], planType: subscription
✅ Calling SubscriptionService.processManualPayment...

[processManualPayment] Starting for userId=[user-id], planType=subscription
[processManualPayment] Profile: {name: [...], surname: [...]}
[processManualPayment] Deactivating old QR codes...
[processManualPayment] Deactivated ALL QR codes for user: null
[processManualPayment] New QR code: {...}
[processManualPayment] QR insert result: null
[processManualPayment] Existing subscription: {id: [...]}
[processManualPayment] Updating EXISTING subscription...
[processManualPayment] Subscription UPDATE result: {...}
[processManualPayment] Final subscription state: {
  status: active,
  current_period_start: [now],
  current_period_end: [now + 30 days]
}
[processManualPayment] ✅ Profile subscription update result: null
[processManualPayment] SUCCESS

✅ processManualPayment returned: true
✅ Subscription activated successfully
✅ Showing success message and scheduling auto-navigation...
✅ Auto-navigating to Members Home after payment success.
```

**Actual Console Output:**
```
[Paste actual logs here]
```

**Result:**
- [ ] ✅ Payment processed successfully
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 5: Verify Database Updates

### Open Supabase SQL Editor and run:

```sql
-- Check subscription status
SELECT 
    id,
    status,
    current_period_start,
    current_period_end,
    current_period_end > now() as is_active
FROM subscriptions 
WHERE user_id = 'YOUR_USER_ID';
```

**Expected Results:**
- status = 'active'
- current_period_end ≈ now + 30 days
- is_active = true

**Actual Results:**
```
[Paste query results here]
```

**Verification:**
- [ ] ✅ Subscription updated correctly
- [ ] ❌ Issue: _______________________

---

```sql
-- Check QR code status
SELECT 
    id,
    is_active,
    expires_at,
    expires_at > now() as is_valid,
    created_at
FROM user_qr_codes 
WHERE user_id = 'YOUR_USER_ID'
ORDER BY created_at DESC
LIMIT 2;  -- Show last 2 to see old and new
```

**Expected Results:**
- Most recent QR: is_active = true, expires_at ≈ now + 30 days
- Previous QR: is_active = false

**Actual Results:**
```
[Paste query results here]
```

**Verification:**
- [ ] ✅ New QR code created and active
- [ ] ✅ Old QR code deactivated
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 6: Verify UI Display

### Check Members Home Page:

**Visual Checklist:**
- [ ] Active QR code displayed (large, scannable)
- [ ] User name displayed correctly
- [ ] Subscription status shows "Active"
- [ ] Days remaining shows ≈ 30 days
- [ ] NO "Subscription expired" message
- [ ] NO renewal popup appears again

**Console Output for UI State:**
```
📊 UI State Debug:
  - has_active_qr: true
  - auto_renew: false
  - days_until_renewal: 30
  - subscription_status: active
📱 UI State: Showing active QR code
```

**Actual Console Output:**
```
[Paste actual logs here]
```

**Screenshot:** [Take a photo of active QR code display]

**Result:**
- [ ] ✅ UI displays active subscription correctly
- [ ] ❌ Issue: _______________________

---

## 🎯 TEST 7: No Renewal Record Warning

### Check final console output for:

**Should NOT see:**
```
[processManualPayment] WARNING: Renewal insert failed (non-critical): 
PostgrestException... row-level security policy
```

**Did you see the warning?**
- [ ] ❌ Yes - RLS fix didn't work
- [ ] ✅ No - RLS fix successful!

---

## 📊 TEST SUMMARY

### Overall Results:

| Test | Status | Notes |
|------|--------|-------|
| 1. Expire Subscription | ⬜ Pass / ⬜ Fail | |
| 2. Renewal Popup Display | ⬜ Pass / ⬜ Fail | |
| 3A. "Not Now" Button | ⬜ Pass / ⬜ Fail | |
| 3B. "Renew" Button | ⬜ Pass / ⬜ Fail | |
| 4. Complete Payment | ⬜ Pass / ⬜ Fail | |
| 5. Database Updates | ⬜ Pass / ⬜ Fail | |
| 6. UI Display | ⬜ Pass / ⬜ Fail | |
| 7. No RLS Warning | ⬜ Pass / ⬜ Fail | |

### Critical Issues Found:
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Minor Issues Found:
1. _______________________________________________
2. _______________________________________________

### Recommendations:
_______________________________________________
_______________________________________________
_______________________________________________

---

## 🔄 Reset for Re-Testing (if needed)

If you want to test again, run this SQL:

```sql
-- Reset subscription to active state
UPDATE subscriptions 
SET status = 'active',
    current_period_end = NOW() + INTERVAL '30 days',
    current_period_start = NOW()
WHERE user_id = 'YOUR_USER_ID';

-- Reactivate most recent QR code
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

## ✅ TEST COMPLETION

**Session End Time:** _______________

**Final Status:**
- [ ] ✅ All tests passed - Ready for production
- [ ] ⚠️ Minor issues - Can deploy with monitoring
- [ ] ❌ Critical issues - Needs fixes before deployment

**Tested By:** _______________
**Signature:** _______________

---

**Next Steps:**
1. [ ] Document all issues in GitHub/Jira
2. [ ] Create bug fix branches if needed
3. [ ] Schedule production deployment
4. [ ] Set up monitoring for renewal metrics
