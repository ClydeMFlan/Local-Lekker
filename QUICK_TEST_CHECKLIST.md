# 🧪 Quick Test Checklist - Renewal Flow

## ✅ Pre-Test Setup

- [ ] App is running on device/emulator
- [ ] You're logged in as a member
- [ ] You can see Members Home Page
- [ ] Supabase SQL Editor is open

## 📋 Test Steps

### 1️⃣ Get Your User ID
```
Look in terminal logs for: "Loading user data for user: [USER_ID]"
Copy this UUID - you'll need it for SQL queries
```

### 2️⃣ Expire Subscription (SQL)
```sql
UPDATE subscriptions 
SET current_period_end = '2025-01-01T00:00:00Z'
WHERE user_id = 'YOUR_USER_ID';
```
- [ ] SQL executed successfully

### 3️⃣ Restart App
```bash
# In terminal:
R  # or flutter run
```
- [ ] App restarted

### 4️⃣ Watch Console Logs
Look for these messages:
- [ ] 🔍 "Checking subscription expiry"
- [ ] ⏰ "Subscription EXPIRED"
- [ ] 🚫 "QR codes deactivated"
- [ ] 💬 "Scheduling renewal popup"
- [ ] 🔔 "Showing renewal popup"

### 5️⃣ Verify Popup Appears
- [ ] Popup appears ~500ms after load
- [ ] Has orange warning icon
- [ ] Title: "Subscription Expired"
- [ ] Shows 3 benefits with checkmarks
- [ ] Green box: "R99.00 for 30 days"
- [ ] Two buttons visible

### 6️⃣ Test "Not Now" Button
- [ ] Click "Not Now"
- [ ] Popup closes
- [ ] Returns to Members Home
- [ ] Shows "Subscription expired" card

### 7️⃣ Test "Renew Subscription" Button
- [ ] Restart app (popup appears again)
- [ ] Click "Renew Subscription"
- [ ] Popup closes
- [ ] Navigates to Payment Options Screen

### 8️⃣ Complete Payment
- [ ] Payment screen loads
- [ ] Select payment method
- [ ] Paystack test page opens
- [ ] Complete test payment
- [ ] Success page appears
- [ ] "Activate Subscription" button visible
- [ ] Click "Activate Subscription"

### 9️⃣ Watch Payment Processing
Look for these logs:
- [ ] 🔘 "MANUAL ACTIVATE BUTTON PRESSED"
- [ ] "[processManualPayment] Starting"
- [ ] "[processManualPayment] Updating EXISTING subscription"
- [ ] "[processManualPayment] SUCCESS"
- [ ] 🚀 "Auto-navigating to Members Home"

### 🔟 Verify Success (Database)
```sql
-- Check subscription
SELECT status, current_period_end 
FROM subscriptions 
WHERE user_id = 'YOUR_USER_ID';
```
- [ ] status = 'active'
- [ ] current_period_end = ~30 days from now

```sql
-- Check QR code
SELECT is_active, expires_at 
FROM user_qr_codes 
WHERE user_id = 'YOUR_USER_ID' 
ORDER BY created_at DESC LIMIT 1;
```
- [ ] is_active = true
- [ ] expires_at = ~30 days from now

### 1️⃣1️⃣ Verify UI State
- [ ] Back on Members Home Page
- [ ] Active QR code displayed
- [ ] No renewal popup (subscription active)
- [ ] Days remaining shown correctly

## 🎯 Success Criteria

All items above checked = ✅ **RENEWAL FLOW WORKING PERFECTLY!**

## 🐛 Common Issues

**Popup doesn't appear?**
→ Check console for error logs
→ Verify subscription status = 'expired' in database
→ Ensure QR codes are deactivated

**Payment succeeds but no renewal?**
→ Check for "[processManualPayment] ERROR" in logs
→ Verify RLS policies are active
→ Check database directly

**Emergency reset:**
```sql
UPDATE subscriptions 
SET status = 'active', 
    current_period_end = NOW() + INTERVAL '30 days'
WHERE user_id = 'YOUR_USER_ID';
```

## 📊 Expected Timeline

- **Expiry Detection**: Instant on app restart
- **Popup Appearance**: 500ms after UI loads
- **Payment Processing**: 2-5 seconds
- **Total Test Time**: 2-3 minutes

---

**Ready to start?** 
1. Copy your User ID from logs
2. Open `TEST_RENEWAL_FLOW.sql`
3. Follow steps 1-12
4. Check off each item above

Good luck! 🚀
