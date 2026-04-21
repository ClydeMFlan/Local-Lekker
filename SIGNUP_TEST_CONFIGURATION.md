# 🧪 Signup Test Configuration
## Test Session: Member & Trusted Partner Signup Validation

**Date:** January 5, 2026  
**Purpose:** End-to-end testing of member and trusted partner signup flows with database validation

---

## 📋 REQUIRED CONFIGURATION

### 1. Environment Setup
**Which .env file to use?**
- [ ] `.env` (default)
- [ ] `.env.development`
- [ ] `.env.production`

**Selected environment:** `.env.production`

**Supabase URL:** `https://qdrotavcmmevhgveodcp.supabase.co`  
**Can we create test users?** [ Y] Yes [ ] No  
**Auto-cleanup required?** [ Y] Yes [ ] No

---

### 2. OTP Verification Strategy

**How will we handle email OTP verification?**

**Option A: Email inbox access**
- [ ] Using this option
- **Test email inbox:** ``
- **Inbox access URL/credentials:** `_______________________`

**Option B: Supabase auto-confirm enabled**
- [ ] Using this option (no OTP needed)
- **Auto-confirm setting:** [ ] Enabled [ ] Disabled

**Option C: Manual Supabase dashboard confirmation**
- [ ] Using this option
- **Supabase dashboard URL:** `_______________________`
- **Will manually confirm via:** Authentication → Users → [user] → Confirm

**Selected strategy:** `Option C`

---

### 3. Payment Testing Strategy

#### For Member Signup:

**Option A: Paystack Test Mode**
- [ ] Using this option
- **Paystack sandbox enabled:** [ ] Yes [N ] No
- **Test card number:** `4084084084084081`
- **Test expiry:** Any future date
- **Test CVV:** `408`
- **Test OTP:** `123456`

**Option B: Trusted Partner Key Signup (Free)**
- [ ] Using this option
- **Test TP key to use:** `_______________________`
- **Key owner/business:** `_______________________`

**Selected strategy:** `_______________________`

#### For Trusted Partner Signup:
- No payment required ✅
- Will complete business profile after OTP

---

### 4. Device/Emulator Configuration

**Test device:**
- [Y ] Android emulator (AVD)
- [ ] Physical Android device
- [ ] iOS simulator
- [ ] Physical iOS device

**Device ID/name:** `Check connected android device`

**Flutter run command to use:**
```bash
flutter run -d [DEVICE_ID]
```

**Actual command:** `_______________________`

---

## 📝 TEST DATA TEMPLATES

### Member Signup Test Data

```yaml
Test Member 1:
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
  Use TP Key: [Yes/No]
  TP Key (if applicable): _______________
```

```yaml
Test Member 2 (for multiple tests):
  Name: Second
  Surname: Tester
  Email: testmember002@example.com
  Password: TestPass123!
  Contact: +27123456002
  Gender: Female
  Ethnicity: White
  Date of Birth: 1995-03-20
  Street: 456 Test Avenue
  Suburb: Rosebank
  City: Johannesburg
  Province: Gauteng
  Use TP Key: [Yes/No]
  TP Key (if applicable): _______________
```

---

### Trusted Partner Signup Test Data

```yaml
Test Trusted Partner 1:
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
  Logo: [Optional - path or skip]
```

```yaml
Test Trusted Partner 2:
  Name: Sarah
  Surname: Vendor
  Email: testpartner002@example.com
  Password: VendorPass123!
  Contact: +27123456102
  Gender: Female
  Ethnicity: Coloured
  Date of Birth: 1988-11-25
  Business Name: The Old Oak Test
  Street: 321 Commerce Street
  Suburb: Fourways
  City: Johannesburg
  Province: Gauteng
  Logo: [Optional - path or skip]
```

---

## 🔍 DATABASE VALIDATION QUERIES

### After Member Signup - Run These Queries:

```sql
-- Replace [EMAIL] with test member email
-- Check auth.users table
SELECT 
    id,
    email,
    email_confirmed_at,
    raw_user_meta_data,
    created_at
FROM auth.users
WHERE email = '[EMAIL]';

-- Check profiles table
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
WHERE email = '[EMAIL]';

-- Check memberships table
SELECT 
    user_id,
    role,
    gateway,
    status,
    created_at
FROM memberships
WHERE user_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');

-- Check subscriptions table (if payment completed)
SELECT 
    id,
    user_id,
    status,
    current_period_start,
    current_period_end,
    created_at
FROM subscriptions
WHERE user_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');

-- Check QR codes (if subscription active)
SELECT 
    id,
    user_id,
    qr_code_data,
    is_active,
    expires_at,
    created_at
FROM user_qr_codes
WHERE user_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');
```

---

### After Trusted Partner Signup - Run These Queries:

```sql
-- Replace [EMAIL] with test TP email
-- Check auth.users table
SELECT 
    id,
    email,
    email_confirmed_at,
    raw_user_meta_data,
    created_at
FROM auth.users
WHERE email = '[EMAIL]';

-- Check profiles table
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
WHERE email = '[EMAIL]';

-- Check memberships table
SELECT 
    user_id,
    role,
    gateway,
    status,
    created_at
FROM memberships
WHERE user_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');

-- Check trusted_partners table
SELECT 
    user_id,
    business_name,
    unique_key,
    paystack_recipient_code,
    created_at
FROM trusted_partners
WHERE user_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');

-- Check businesses table (after business profile completion)
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
WHERE owner_member_id = (SELECT id FROM profiles WHERE email = '[EMAIL]');
```

---

## ✅ SUCCESS CRITERIA CHECKLIST

### Member Signup Flow
- [ ] Email normalized to lowercase in database
- [ ] Profile created with all fields populated
- [ ] Membership record created with role='member'
- [ ] If payment completed: subscription status='active'
- [ ] If payment completed: QR code generated and active
- [ ] If TP key used: subscription status='active' without payment
- [ ] If TP key used: membership gateway='trusted_partner_key'
- [ ] No errors in Flutter console during signup
- [ ] User can sign in after signup

### Trusted Partner Signup Flow
- [ ] Email normalized to lowercase in database
- [ ] Profile created with role='trusted_partner'
- [ ] Membership record created with role='trusted_partner'
- [ ] Trusted_partners record created
- [ ] Unique key generated (12 characters)
- [ ] Business profile page displays after OTP
- [ ] After business completion: businesses table populated
- [ ] Logo uploaded successfully (if provided)
- [ ] No errors in Flutter console during signup
- [ ] User can sign in as trusted partner

---

## 🐛 ISSUE TRACKING

### Issues Found During Testing

**Issue #1:**
- **Flow:** [ ] Member [ ] Trusted Partner
- **Step:** `_______________________`
- **Expected:** `_______________________`
- **Actual:** `_______________________`
- **Error message:** `_______________________`
- **Screenshot/logs:** `_______________________`

**Issue #2:**
- **Flow:** [ ] Member [ ] Trusted Partner
- **Step:** `_______________________`
- **Expected:** `_______________________`
- **Actual:** `_______________________`
- **Error message:** `_______________________`
- **Screenshot/logs:** `_______________________`

**Issue #3:**
- **Flow:** [ ] Member [ ] Trusted Partner
- **Step:** `_______________________`
- **Expected:** `_______________________`
- **Actual:** `_______________________`
- **Error message:** `_______________________`
- **Screenshot/logs:** `_______________________`

---

## 📊 TEST RESULTS SUMMARY

### Member Signup Tests
**Total Tests:** `_______`  
**Passed:** `_______`  
**Failed:** `_______`  
**Blocked:** `_______`

**Notes:**
```
[Add detailed notes here]
```

### Trusted Partner Signup Tests
**Total Tests:** `_______`  
**Passed:** `_______`  
**Failed:** `_______`  
**Blocked:** `_______`

**Notes:**
```
[Add detailed notes here]
```

---

## 🧹 CLEANUP COMMANDS

### Delete Test Users After Testing

```sql
-- Replace [EMAIL] with test user email to delete

-- Get user ID first
SELECT id, email FROM profiles WHERE email = '[EMAIL]';
-- Copy the ID, then:

-- Delete in this order (respects foreign keys):
DELETE FROM user_qr_codes WHERE user_id = '[USER_ID]';
DELETE FROM subscriptions WHERE user_id = '[USER_ID]';
DELETE FROM memberships WHERE user_id = '[USER_ID]';
DELETE FROM businesses WHERE owner_member_id = '[USER_ID]';
DELETE FROM trusted_partners WHERE user_id = '[USER_ID]';
DELETE FROM profiles WHERE id = '[USER_ID]';

-- Finally, delete from auth.users via Supabase Dashboard:
-- Authentication → Users → Find user → Delete
```

**Test users cleaned up:**
- [ ] testmember001@example.com
- [ ] testmember002@example.com
- [ ] testpartner001@example.com
- [ ] testpartner002@example.com

---

## 📝 ADDITIONAL NOTES

```
[Add any additional context, observations, or recommendations here]
```

---

**Test Completed By:** `_______________________`  
**Completion Date:** `_______________________`  
**Sign-off:** [ ] Ready for production [ ] Issues found - needs fixes
