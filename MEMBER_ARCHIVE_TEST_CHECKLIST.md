# Member Archive Re-signup Test Checklist

## Pre-Deployment Checklist
- [ ] Run `deploy_member_archive_system.sql` in Supabase SQL Editor
- [ ] Verify all checks pass (table created, indexes, RLS policies)
- [ ] Confirm Flutter app code is deployed (already in codebase)

## Test Scenario: bekkerhenno518@gmail.com

### SCENARIO 1: Admin Deletes Member ✅
**Expected**: Member archived and removed from database

**Steps**:
1. Login as admin to Local Lekker app
2. Navigate to Admin → Members List
3. Find member: `bekkerhenno518@gmail.com`
4. Click Delete button
5. Confirm deletion

**Verify in Supabase SQL Editor**:
```sql
-- Should return NO rows (member deleted)
SELECT * FROM profiles WHERE email = 'bekkerhenno518@gmail.com';

-- Should return 1 row (member archived)
SELECT * FROM archived_members WHERE email = 'bekkerhenno518@gmail.com';

-- Should return 0 rows (auth user deleted)
SELECT * FROM auth.users WHERE email = 'bekkerhenno518@gmail.com';
```

**Expected Results**:
- ✅ No profile in `profiles` table
- ✅ One entry in `archived_members` table with all user data
- ✅ No auth user in `auth.users`

---

### SCENARIO 2: Deleted Member Tries to Sign In ❌
**Expected**: Email not found, cannot sign in

**Steps**:
1. Open Local Lekker app (logged out)
2. Click "Sign In"
3. Enter email: `bekkerhenno518@gmail.com`
4. Enter any password
5. Click "Sign In"

**Expected Results**:
- ✅ Error message: "Invalid login credentials" or "User not found"
- ✅ Cannot access app
- ✅ Prompted to sign up instead

---

### SCENARIO 3: Deleted Member Re-signs Up 🎉
**Expected**: Archive detected, form autofilled, signup succeeds

**Steps**:
1. Open Local Lekker app (logged out)
2. Click "Sign Up as Member"
3. Enter email: `bekkerhenno518@gmail.com`
4. Wait ~500ms (email debounce)

**Expected UI Behavior**:
- ✅ Loading spinner appears in email field (checkingEmail = true)
- ✅ Green snackbar appears: "Welcome back! We found your previous details and autofilled the form."
- ✅ All fields autofill:
  - Name
  - Surname
  - Street
  - Suburb
  - City
  - Province (dropdown)
  - Contact
  - Gender (dropdown)
  - Ethnicity (dropdown)
  - Date of Birth

**Complete Signup**:
5. Enter new password: `Test123!`
6. Confirm password: `Test123!`
7. Review autofilled details (should match archived data)
8. Click "Sign Up"
9. Complete OTP verification (check email)
10. Proceed to payment screen

**Verify in Supabase**:
```sql
-- Should return NEW user (different UUID from original)
SELECT id, email, name, surname FROM profiles 
WHERE email = 'bekkerhenno518@gmail.com';

-- Should STILL return archived member (archive persists)
SELECT original_user_id, email, name, deleted_at 
FROM archived_members 
WHERE email = 'bekkerhenno518@gmail.com';

-- Should return NEW auth user (different from original_user_id)
SELECT id, email FROM auth.users 
WHERE email = 'bekkerhenno518@gmail.com';
```

**Expected Results**:
- ✅ New profile created with fresh UUID
- ✅ Archive still exists (not deleted)
- ✅ New auth.users entry (different UUID than `original_user_id`)
- ✅ Member can complete payment and use app normally

---

## Debug Checks

### If Autofill Doesn't Work

**Check 1: Database Query**
```sql
-- Test the exact query the app uses
SELECT id, original_user_id, email, name, surname, street, suburb, city, province, 
       contact, gender, ethnicity, date_of_birth, deleted_at, last_subscription_status
FROM archived_members
WHERE LOWER(email) = LOWER('bekkerhenno518@gmail.com')
ORDER BY deleted_at DESC
LIMIT 1;
```
- Should return 1 row with all data
- If 0 rows: Archive wasn't created during deletion

**Check 2: RLS Policies**
```sql
-- Verify anon can read
SELECT policyname, permissive, roles, cmd 
FROM pg_policies 
WHERE tablename = 'archived_members' AND cmd = 'SELECT';
```
- Should show policy allowing anon SELECT
- If missing: Re-run `deploy_member_archive_system.sql`

**Check 3: Flutter Logs**
- Open browser DevTools → Console
- Enter email in signup form
- Look for logs:
  - `getArchivedMemberByEmail: looking up bekkerhenno518@gmail.com`
  - `getArchivedMemberByEmail: archived member found for ...`
  - `Autofilling signup form from archived member data`
- If missing: Check `SupabaseService.getArchivedMemberByEmail()` method exists

**Check 4: Network Request**
- DevTools → Network tab
- Filter: `archived_members`
- Should see POST request to Supabase
- Check response: Should contain member data

---

## Success Criteria

### ✅ System Working Correctly When:
1. Admin can delete members successfully
2. Deleted member data appears in `archived_members` table
3. Deleted member cannot sign in (auth.users removed)
4. Deleted member sees autofill when entering email on signup
5. Deleted member can complete new signup with archived data
6. New signup creates fresh profile with new UUID
7. Archive persists after re-signup (for future reference)

### ❌ Issues to Fix:
- No archive created → Check `admin_delete_member_data()` function update
- Autofill doesn't work → Check RLS policies allow anon SELECT
- Email lookup fails → Check index on `LOWER(email)`
- Wrong data autofilled → Check `_prefillFromArchivedMember()` mapping

---

## Rollback Plan (If Issues)

**Disable Autofill Feature**:
```dart
// In members_signup_page.dart, comment out archive check:
// final archivedMember = await SupabaseService.instance.getArchivedMemberByEmail(trimmed);
// if (archivedMember != null) { ... }
```

**Remove Archive Function** (drastic):
```sql
-- Revert to old function (without archiving)
CREATE OR REPLACE FUNCTION admin_delete_member_data(member_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
-- (use old function code from admin_delete_functions.sql)
$$;
```

**Drop Table** (if needed):
```sql
DROP TABLE IF EXISTS public.archived_members CASCADE;
```

---

## Post-Deployment Monitoring

**Weekly Check**:
```sql
-- Archive growth
SELECT COUNT(*) as total_archived FROM archived_members;

-- Recent archives (last 7 days)
SELECT email, name, deleted_at 
FROM archived_members 
WHERE deleted_at > NOW() - INTERVAL '7 days'
ORDER BY deleted_at DESC;
```

**Monthly Audit**:
```sql
-- Archive vs Active members ratio
SELECT 
    (SELECT COUNT(*) FROM profiles WHERE role = 'member') as active_members,
    (SELECT COUNT(*) FROM archived_members) as archived_members,
    ROUND(
        (SELECT COUNT(*)::numeric FROM archived_members) / 
        NULLIF((SELECT COUNT(*) FROM profiles WHERE role = 'member'), 0) * 100, 
        2
    ) as archive_percentage;
```

---

## Test Result Sign-off

**Tested By**: _________________  
**Date**: _________________  
**Environment**: Production / Staging  

**Results**:
- [ ] SCENARIO 1: Admin deletion and archiving works
- [ ] SCENARIO 2: Deleted member cannot sign in
- [ ] SCENARIO 3: Deleted member re-signup autofills correctly

**Issues Found**: _________________  
**Status**: ✅ PASS / ❌ FAIL / ⚠️ PARTIAL
