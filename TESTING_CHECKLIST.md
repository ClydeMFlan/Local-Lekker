# Testing Checklist - Member Sign-In Flow Fix

## ✅ Pre-Test Verification
- [ ] Flutter app is running on device/emulator
- [ ] Supabase connection is active
- [ ] .env file has correct Supabase credentials
- [ ] Paystack integration is configured

## 🧪 Test Case 1: Email Not Found Issue (PRIMARY FIX)
**Scenario**: Member signs out before payment, then tries to sign in

### Steps:
1. [ ] Open app → Click "Sign Up" → Choose "Member"
2. [ ] Fill form with:
   - Name: Test
   - Surname: User
   - Email: **testuser@example.com** (note: lowercase)
   - Password: Test1234!
   - (Fill other required fields)
3. [ ] Submit form → Check email for OTP
4. [ ] Enter OTP → Should see PaymentOptionsScreen
5. [ ] **IMPORTANT**: Click "Sign Out" button (don't pay yet)
6. [ ] Should return to WelcomePage
7. [ ] Click "Sign In"
8. [ ] Enter email: **testuser@example.com**
9. [ ] **EXPECTED**: ✅ Green checkmark appears (email found)
10. [ ] **EXPECTED**: Password field appears
11. [ ] Enter password: Test1234!
12. [ ] Click "Sign In"
13. [ ] **EXPECTED**: Successfully signs in
14. [ ] **EXPECTED**: Navigates to PaymentRequiredScreen (not error)
15. [ ] Complete payment via Paystack test mode
16. [ ] **EXPECTED**: Lands on MembersHomePage with QR code

### ❌ Old Behavior (Bug):
- Step 9: Red X appears with "Email not found"
- User couldn't proceed

### ✅ New Behavior (Fixed):
- Step 9: Green checkmark - email is found
- Step 14: Directed to payment screen

---

## 🧪 Test Case 2: Email Case Insensitivity
**Scenario**: Email case shouldn't matter

### Steps:
1. [ ] Sign up with: **TestCase@Example.COM**
2. [ ] Complete OTP verification
3. [ ] Sign out from PaymentOptionsScreen
4. [ ] Try to sign in with: **testcase@example.com** (all lowercase)
5. [ ] **EXPECTED**: ✅ Email is found (checkmark appears)
6. [ ] Enter password → Sign in
7. [ ] **EXPECTED**: Successfully authenticated

### Testing Matrix:
| Sign Up Email | Sign In Email | Should Work? |
|--------------|---------------|--------------|
| test@example.com | test@example.com | ✅ Yes |
| test@example.com | TEST@EXAMPLE.COM | ✅ Yes |
| Test@Example.Com | test@example.com | ✅ Yes |
| MyEmail@Test.Co | myemail@test.co | ✅ Yes |

---

## 🧪 Test Case 3: Complete Happy Path
**Scenario**: Member completes entire flow without signing out

### Steps:
1. [ ] Sign up as new member
2. [ ] Enter OTP
3. [ ] See PaymentOptionsScreen
4. [ ] **Don't sign out** - proceed with payment
5. [ ] Complete Paystack payment
6. [ ] **EXPECTED**: Lands on MembersHomePage
7. [ ] **EXPECTED**: Can see QR code
8. [ ] Sign out
9. [ ] Sign in again
10. [ ] **EXPECTED**: Goes directly to MembersHomePage (not payment screen)

---

## 🧪 Test Case 4: Email with Spaces
**Scenario**: User accidentally adds spaces to email

### Steps:
1. [ ] Sign up with: **" test@example.com "** (with spaces)
2. [ ] Complete signup flow
3. [ ] Sign out
4. [ ] Sign in with: **"test@example.com"** (no spaces)
5. [ ] **EXPECTED**: ✅ Email is found and works

---

## 🔍 Debug Logs to Watch

### During Email Check:
```
🔍 checkEmailExists: Checking email: "testuser@example.com"
🔍 checkEmailExists: Email exists: true
```

### During Sign-In:
```
🔐 SupabaseService: Attempting sign in for testuser@example.com
🔐 SupabaseService: Sign in successful for testuser@example.com, user: <uuid>
```

### During Navigation:
```
NavigationService: Checking subscription status
NavigationService: Subscription status: pending
🎬 LoadingScreen: Navigating to PaymentRequiredScreen
```

---

## 🐛 Known Issues to Verify Fixed

### Issue 1: "Email not found" on valid email ✅ FIXED
- **Cause**: Email case mismatch between profiles and sign-in
- **Fix**: Normalize all emails to lowercase

### Issue 2: Wrong screen after sign-in ✅ FIXED
- **Cause**: Subscription status not properly checked
- **Fix**: Check subscriptions table first, then profiles.subscription

### Issue 3: Can't sign in after signup without payment ✅ FIXED
- **Cause**: Email validation failed for users with pending subscription
- **Fix**: Improved email lookup and subscription routing

---

## 📝 Expected Console Output (Success)

```
🔍 checkEmailExists: Checking email: "testuser@example.com"
🔍 checkEmailExists: Email exists: true
🔐 SupabaseService: Attempting sign in for testuser@example.com
🔐 SupabaseService: Sign in successful for testuser@example.com, user: abc-123-def
🎬 LoadingScreen: Performing auto-transition after authentication
NavigationService: Checking subscription status
📊 Subscription status: pending
🎬 LoadingScreen: Navigating to PaymentRequiredScreen with fade transition
```

---

## ⚠️ Failure Indicators

### If email still not found:
1. Check Supabase RLS policies on profiles table
2. Verify profile was created during signup
3. Check database directly: `SELECT email FROM profiles WHERE email = 'testuser@example.com'`

### If wrong screen after sign-in:
1. Check subscription status in database
2. Verify NavigationService logs
3. Check if subscriptions table exists and has correct schema

### If sign-in fails with valid password:
1. Check Supabase auth logs
2. Verify email exists in auth.users table
3. Check for rate limiting issues

---

## 🎯 Success Criteria

✅ **All tests must pass:**
1. Email found regardless of case
2. Members with pending payment can sign in
3. After sign-in, directed to PaymentRequiredScreen (if no payment)
4. After payment, directed to MembersHomePage
5. No "email not found" errors for valid accounts

---

## 📞 Support Commands

### Check profile in database:
```sql
SELECT id, email, subscription FROM profiles WHERE email = 'testuser@example.com';
```

### Check subscription:
```sql
SELECT * FROM subscriptions WHERE user_id = '<user-id>';
```

### Reset test user:
```sql
-- Clean up test accounts
DELETE FROM subscriptions WHERE user_id IN (SELECT id FROM profiles WHERE email LIKE 'test%');
DELETE FROM profiles WHERE email LIKE 'test%';
-- Note: Also delete from auth.users via Supabase dashboard
```
