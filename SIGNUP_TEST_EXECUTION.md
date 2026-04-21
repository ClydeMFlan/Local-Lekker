# 🧪 SIGNUP TEST EXECUTION LOG
## Session: January 5, 2026

**Configuration:** Production environment (.env.production)  
**Device:** SM S918B (Android)  
**OTP Strategy:** Manual Supabase dashboard confirmation

---

## 📱 TEST 1: MEMBER SIGNUP FLOW

### Step 1: Navigate to Signup
- [ ] App launched successfully
- [ ] On Welcome Page
- [ ] Click "Sign Up" button
- [ ] Click "Member" option

### Step 2: Fill Member Signup Form

**Use Test Member 1 Data:**
```
Name: Test
Surname: Member
Email: testmember001@example.com
Password: TestPass123!
Contact: +27123456001
Gender: Male
Ethnicity: Black
Date of Birth: 1990-01-15
Street: 123 Test Street
Suburb: Sandton
City: Johannesburg
Province: Gauteng
```

**Form Completion:**
- [ ] Name entered
- [ ] Surname entered
- [ ] Date of Birth selected
- [ ] Gender selected
- [ ] Ethnicity selected
- [ ] Street address entered
- [ ] Suburb entered
- [ ] City entered
- [ ] Province selected
- [ ] Contact number entered
- [ ] Email entered
- [ ] Password entered
- [ ] Confirm password entered
- [ ] "I have a Trusted Partner key" checkbox: UNCHECKED

### Step 3: Submit Signup
- [ ] Click "Create Account" button
- [ ] Form validation passed
- [ ] OTP dialog appears
- [ ] Message: "Please enter the OTP sent to your email"

**Console Output to Watch For:**
```
🔐 SupabaseService: Attempting sign in for testmember001@example.com
User signup initiated
Signup response: ...
User created successfully: testmember001@example.com
Please enter the OTP sent to your email
```

**Actual Console Output:**
```
[Paste relevant logs here]
```

### Step 4: Confirm Email in Supabase Dashboard

**Steps:**
1. Open Supabase Dashboard: https://supabase.com/dashboard/project/qdrotavcmmevhgveodcp
2. Go to Authentication → Users
3. Find user: testmember001@example.com
4. Click on the user
5. Click "Confirm user" button
6. User should show as "Confirmed"

**Result:**
- [ ] User found in dashboard
- [ ] User confirmed successfully
- **User ID (copy this):** `_______________________`

### Step 5: Enter OTP in App

**Note:** Since we're using manual confirmation, we need to find the actual OTP code.

**Option A: Check email sent**
- Check the email inbox for testmember001@example.com
- Copy the 6-digit OTP code
- **OTP Code:** `_______________________`

**Option B: Use any 6-digit code (if auto-confirm worked)**
- Try: `123456` or `000000`

- [ ] Enter OTP code in dialog
- [ ] Click "Verify" button

**Expected Behavior:**
- [ ] OTP verification succeeds
- [ ] Profile creation begins
- [ ] Success message appears

**Console Output to Watch For:**
```
OTP verification successful, userId: [user-id]
Final user ID for profile creation: [user-id]
Current user from Supabase: ...
User profile created successfully
About to trigger payment navigation
```

**Actual Console Output:**
```
[Paste relevant logs here]
```

### Step 6: Payment Screen Navigation

**Expected:**
- [ ] OTP dialog closes
- [ ] Navigates to PaymentOptionsScreen
- [ ] Screen shows "Payment Options" or similar title
- [ ] Plan type: Basic/Subscription
- [ ] Price: R99.00
- [ ] Duration: 30 days

**Actual Result:**
- [ ] ✅ Navigation successful
- [ ] ❌ Issue: `_______________________`

### Step 7: Complete Paystack Payment (SKIP FOR NOW)

**Decision:** [ ] Complete payment [ ] Skip payment for database check

**If completing payment:**
- Use Paystack test card
- Complete payment flow
- Verify QR code generation

**If skipping:**
- Note that subscription will be "pending"
- QR code will NOT be generated yet

---

## 🔍 DATABASE VALIDATION - MEMBER SIGNUP

### Query 1: Check auth.users

```sql
SELECT 
    id,
    email,
    email_confirmed_at,
    raw_user_meta_data,
    created_at
FROM auth.users
WHERE email = 'testmember001@example.com';
```

**Expected Results:**
- ✅ User exists
- ✅ Email is lowercase: testmember001@example.com
- ✅ email_confirmed_at is populated
- ✅ raw_user_meta_data contains: user_type='member', name, surname, etc.

**Actual Results:**
```
id: _______________________
email: _______________________
email_confirmed_at: _______________________
raw_user_meta_data: 
[Paste JSON here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 2: Check profiles table

```sql
SELECT 
    id,
    email,
    name,
    surname,
    role,
    subscription,
    gender,
    ethnicity,
    date_of_birth,
    street,
    suburb,
    city,
    province,
    contact,
    created_at
FROM profiles
WHERE email = 'testmember001@example.com';
```

**Expected Results:**
- ✅ Profile exists
- ✅ Email is lowercase: testmember001@example.com
- ✅ name = 'Test'
- ✅ surname = 'Member'
- ✅ role = 'member'
- ✅ subscription = 'pending' (or 'active' if payment completed)
- ✅ gender = 'Male'
- ✅ ethnicity = 'Black'
- ✅ date_of_birth = '1990-01-15'
- ✅ All address fields populated
- ✅ contact = '+27123456001'

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

**Issues Found:**
```
[List any missing or incorrect fields]
```

---

### Query 3: Check memberships table

```sql
SELECT 
    user_id,
    role,
    gateway,
    status,
    created_at
FROM memberships
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testmember001@example.com');
```

**Expected Results:**
- ✅ Membership exists
- ✅ role = 'member'
- ✅ gateway = 'user_signup'
- ✅ status = (depends on implementation)

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 4: Check subscriptions table (if payment completed)

```sql
SELECT 
    id,
    user_id,
    status,
    current_period_start,
    current_period_end,
    created_at
FROM subscriptions
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testmember001@example.com');
```

**Expected Results (if payment skipped):**
- ℹ️ No rows (subscription created only after payment)

**Expected Results (if payment completed):**
- ✅ Subscription exists
- ✅ status = 'active'
- ✅ current_period_end is 30 days from now

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail [ ] N/A (payment skipped)

---

### Query 5: Check user_qr_codes table (if payment completed)

```sql
SELECT 
    id,
    user_id,
    qr_code_data,
    is_active,
    expires_at,
    created_at
FROM user_qr_codes
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testmember001@example.com');
```

**Expected Results (if payment skipped):**
- ℹ️ No rows (QR code generated only after payment)

**Expected Results (if payment completed):**
- ✅ QR code exists
- ✅ is_active = true
- ✅ qr_code_data is populated
- ✅ expires_at is 30 days from now

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail [ ] N/A (payment skipped)

---

## 📊 MEMBER SIGNUP TEST SUMMARY

**Overall Status:** [ ] ✅ PASS [ ] ⚠️ PARTIAL PASS [ ] ❌ FAIL

**Critical Issues:**
```
[List any critical issues that would prevent production use]
```

**Non-Critical Issues:**
```
[List any minor issues or inconsistencies]
```

**Recommendations:**
```
[Any recommendations for improvements]
```

---

## 📱 TEST 2: TRUSTED PARTNER SIGNUP FLOW

### Step 1: Navigate to Signup
- [ ] Return to Welcome Page (sign out if needed)
- [ ] Click "Sign Up" button
- [ ] Click "Trusted Partner" option

### Step 2: Fill Trusted Partner Signup Form

**Use Test Trusted Partner 1 Data:**
```
Name: John
Surname: Partner
Email: testpartner001@example.com
Password: PartnerPass123!
Contact: +27123456101
Gender: Male
Ethnicity: Indian
Date of Birth: 1985-07-10
Business Name: Test Business 1
Street: 789 Business Road
Suburb: Bryanston
City: Johannesburg
Province: Gauteng
```

**Form Completion:**
- [ ] Name entered
- [ ] Surname entered
- [ ] Gender selected
- [ ] Ethnicity selected
- [ ] Date of Birth selected
- [ ] Business Name entered
- [ ] Logo: SKIP (optional)
- [ ] Street address entered (minimal)
- [ ] Suburb entered (minimal)
- [ ] City entered (minimal)
- [ ] Province selected (minimal)
- [ ] Contact number entered (optional)
- [ ] Email entered
- [ ] Password entered
- [ ] Confirm password entered

### Step 3: Submit Signup
- [ ] Click "Create Account" button
- [ ] Form validation passed
- [ ] OTP dialog appears

**Console Output to Watch For:**
```
Signup response: ...
Please enter the OTP sent to your email
```

**Actual Console Output:**
```
[Paste relevant logs here]
```

### Step 4: Confirm Email in Supabase Dashboard

**Steps:**
1. Open Supabase Dashboard
2. Go to Authentication → Users
3. Find user: testpartner001@example.com
4. Click on the user
5. Click "Confirm user" button

**Result:**
- [ ] User found in dashboard
- [ ] User confirmed successfully
- **User ID (copy this):** `_______________________`

### Step 5: Enter OTP and Verify

- [ ] Enter OTP code in dialog
- [ ] Click "Verify" button

**Expected Behavior:**
- [ ] OTP verification succeeds
- [ ] Profile creation begins
- [ ] Trusted partner record created
- [ ] Membership record created
- [ ] Navigation to BusinessProfilePage

**Console Output to Watch For:**
```
OTP verification successful, userId: [user-id]
Trusted partner profile created successfully via createUserProfile
Trusted partner record created successfully
Membership record created successfully
```

**Actual Console Output:**
```
[Paste relevant logs here]
```

### Step 6: Business Profile Page

**Expected:**
- [ ] Navigates to Business Profile Page
- [ ] Initial business name pre-filled: "Test Business 1"
- [ ] Form shows all business detail fields

**Actual Result:**
- [ ] ✅ Navigation successful
- [ ] ❌ Issue: `_______________________`

### Step 7: Complete Business Profile (OPTIONAL)

**Decision:** [ ] Complete business profile [ ] Skip for database check

**If completing:**
- Fill in all required business fields
- Upload logo if needed
- Complete banking details
- Save business profile

---

## 🔍 DATABASE VALIDATION - TRUSTED PARTNER SIGNUP

### Query 1: Check auth.users

```sql
SELECT 
    id,
    email,
    email_confirmed_at,
    raw_user_meta_data,
    created_at
FROM auth.users
WHERE email = 'testpartner001@example.com';
```

**Expected Results:**
- ✅ User exists
- ✅ Email is lowercase: testpartner001@example.com
- ✅ email_confirmed_at is populated
- ✅ raw_user_meta_data contains: user_type='trusted_partner'

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 2: Check profiles table

```sql
SELECT 
    id,
    email,
    name,
    surname,
    role,
    subscription,
    gender,
    ethnicity,
    date_of_birth,
    contact,
    created_at
FROM profiles
WHERE email = 'testpartner001@example.com';
```

**Expected Results:**
- ✅ Profile exists
- ✅ Email is lowercase: testpartner001@example.com
- ✅ name = 'John'
- ✅ surname = 'Partner'
- ✅ role = 'trusted_partner'
- ✅ subscription = 'active' (TPs don't need paid subscription)
- ✅ gender = 'Male'
- ✅ ethnicity = 'Indian'
- ✅ date_of_birth = '1985-07-10'
- ✅ contact = '+27123456101'

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 3: Check memberships table

```sql
SELECT 
    user_id,
    role,
    gateway,
    status,
    created_at
FROM memberships
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testpartner001@example.com');
```

**Expected Results:**
- ✅ Membership exists
- ✅ role = 'trusted_partner'
- ✅ gateway = 'trusted_partner_signup'

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 4: Check trusted_partners table

```sql
SELECT 
    user_id,
    business_name,
    unique_key,
    paystack_recipient_code,
    created_at
FROM trusted_partners
WHERE user_id = (SELECT id FROM profiles WHERE email = 'testpartner001@example.com');
```

**Expected Results:**
- ✅ Trusted partner record exists
- ✅ business_name is populated (might be empty string initially)
- ✅ unique_key is generated (12 characters)
- ℹ️ paystack_recipient_code might be null initially

**Actual Results:**
```
[Paste query results here]
```

**Copy the unique_key here (for future TP key tests):** `_______________________`

**Status:** [ ] ✅ Pass [ ] ❌ Fail

---

### Query 5: Check businesses table (if business profile completed)

```sql
SELECT 
    id,
    owner_member_id,
    name,
    address,
    contact_email,
    contact_number,
    logo_url,
    created_at
FROM businesses
WHERE owner_member_id = (SELECT id FROM profiles WHERE email = 'testpartner001@example.com');
```

**Expected Results (if business profile skipped):**
- ℹ️ No rows (business created only after completing business profile)

**Expected Results (if business profile completed):**
- ✅ Business record exists
- ✅ name = 'Test Business 1'
- ✅ All fields populated

**Actual Results:**
```
[Paste query results here]
```

**Status:** [ ] ✅ Pass [ ] ❌ Fail [ ] N/A (business profile skipped)

---

## 📊 TRUSTED PARTNER SIGNUP TEST SUMMARY

**Overall Status:** [ ] ✅ PASS [ ] ⚠️ PARTIAL PASS [ ] ❌ FAIL

**Critical Issues:**
```
[List any critical issues that would prevent production use]
```

**Non-Critical Issues:**
```
[List any minor issues or inconsistencies]
```

**Recommendations:**
```
[Any recommendations for improvements]
```

---

## 🎯 FINAL TEST SESSION SUMMARY

### Member Signup Flow
- **Status:** [ ] ✅ PASS [ ] ⚠️ PARTIAL [ ] ❌ FAIL
- **Database Records:** [ ] ✅ Correct [ ] ❌ Issues
- **Critical Issues:** `_______________________`

### Trusted Partner Signup Flow
- **Status:** [ ] ✅ PASS [ ] ⚠️ PARTIAL [ ] ❌ FAIL
- **Database Records:** [ ] ✅ Correct [ ] ❌ Issues
- **Critical Issues:** `_______________________`

### Production Readiness
- [ ] ✅ Ready for production
- [ ] ⚠️ Minor fixes needed
- [ ] ❌ Critical fixes required

### Next Steps
```
[List any required fixes or follow-up actions]
```

---

**Test Completed By:** AI Agent + User  
**Completion Date:** January 5, 2026  
**Total Test Duration:** `_______________________`
