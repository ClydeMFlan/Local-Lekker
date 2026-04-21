# Complete Migration Guide - Trusted Partner Bank Accounts

## 🎯 Goal
Change `trusted_partner_bank_accounts` from using `business_id` to `user_id` for direct user-to-bank account relationship.

---

## 📋 Execution Order

### Step 1: Run Schema Migration
**File:** `fix_trusted_partner_bank_accounts_schema.sql`

This script will:
- ✅ Add `user_id` column
- ✅ Migrate existing data from `business_id` to `user_id`
- ✅ Update foreign key constraints
- ✅ Create indexes

**Execute in Supabase SQL Editor:**
```sql
-- Copy and paste entire content of: fix_trusted_partner_bank_accounts_schema.sql
```

**Expected result:** No errors, migration completes successfully.

---

### Step 2: Clean Up RLS Policies
**File:** `cleanup_trusted_partner_bank_accounts_rls.sql`

This script will:
- ✅ Remove old "Business owners..." policies
- ✅ Remove duplicate "Users..." policies
- ✅ Create fresh `user_id` based policies

**Execute in Supabase SQL Editor:**
```sql
-- Copy and paste entire content of: cleanup_trusted_partner_bank_accounts_rls.sql
```

**Expected result:** Only 4 policies should exist:
- Users can view own bank accounts
- Users can insert own bank accounts
- Users can update own bank accounts
- Users can delete own bank accounts

---

### Step 3: Verify Migration Success

Run these verification queries:

#### Query 1: Check all bank accounts have user_id
```sql
SELECT 
    tpba.id,
    tpba.user_id,
    tpba.business_id,  -- Should still exist but can be null
    tpba.account_holder_name,
    tpba.bank_name,
    p.name,
    p.surname,
    p.email
FROM 
    trusted_partner_bank_accounts tpba
    JOIN profiles p ON tpba.user_id = p.id
WHERE 
    p.role = 'trusted_partner';
```

**Expected:** All records should have `user_id` populated with valid profile IDs.

#### Query 2: Check for orphaned records
```sql
SELECT 
    tpba.id,
    tpba.user_id,
    tpba.account_holder_name
FROM 
    trusted_partner_bank_accounts tpba
    LEFT JOIN profiles p ON tpba.user_id = p.id
WHERE 
    p.id IS NULL;
```

**Expected:** 0 rows (no orphaned records).

#### Query 3: Verify RLS policies
```sql
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM 
    pg_policies
WHERE 
    tablename = 'trusted_partner_bank_accounts'
ORDER BY 
    policyname;
```

**Expected:** Only 4 policies, all starting with "Users can...".

---

### Step 4: Test Application

#### Test 1: New Trusted Partner Sign-Up
1. Open app and navigate to trusted partner sign-up
2. Complete all fields including DOB
3. Add bank account details
4. Submit form
5. **Verify:** Bank account saves with `user_id` (check database)

#### Test 2: Existing Trusted Partner
1. Login as existing trusted partner
2. Navigate to profile/settings
3. View bank account details
4. **Verify:** Bank account displays correctly
5. Edit bank account details
6. Save changes
7. **Verify:** Changes persist in database

#### Test 3: Payment Flow
1. Create a test discount
2. Process a test payment
3. **Verify:** Bank account fetched correctly for payout
4. **Verify:** No errors in logs

---

## 🔍 Troubleshooting

### Problem: "column user_id does not exist"
**Solution:** Run Step 1 (schema migration) again.

### Problem: RLS policy errors
**Solution:** Run Step 2 (cleanup RLS) to remove old policies.

### Problem: "null value in column user_id violates not-null constraint"
**Solution:** 
1. Check if migration script ran completely
2. Verify existing records were migrated:
```sql
SELECT COUNT(*) FROM trusted_partner_bank_accounts WHERE user_id IS NULL;
```
3. If records exist without user_id, manually update them

### Problem: App shows "Failed to save bank account"
**Check:**
1. Are RLS policies correct? (Run verification Query 3)
2. Is the user logged in? (Check `auth.uid()`)
3. Check browser console for error details

---

## 📊 Before vs After

### Before Migration
```
Database: business_id → businesses table
Code: BankAccount.businessId, saveBankAccount(businessId: ...)
Policies: "Business owners can..."
```

### After Migration
```
Database: user_id → profiles/auth.users
Code: BankAccount.userId, saveBankAccount(userId: ...)
Policies: "Users can..."
```

---

## ✅ Success Checklist

- [ ] Schema migration executed successfully
- [ ] RLS policies cleaned up (only 4 policies exist)
- [ ] All existing bank accounts have `user_id` populated
- [ ] No orphaned records found
- [ ] New sign-up saves bank account with `user_id`
- [ ] Existing users can view their bank accounts
- [ ] Existing users can edit their bank accounts
- [ ] Payment flow works correctly
- [ ] No errors in application logs

---

## 🚨 Rollback (If Needed)

If you need to rollback:

```sql
-- 1. Restore business_id as primary foreign key
ALTER TABLE trusted_partner_bank_accounts
DROP CONSTRAINT IF EXISTS trusted_partner_bank_accounts_user_id_fkey;

ALTER TABLE trusted_partner_bank_accounts
ADD CONSTRAINT trusted_partner_bank_accounts_business_id_fkey 
FOREIGN KEY (business_id) REFERENCES businesses(id);

-- 2. Restore old RLS policies
-- (Manually recreate "Business owners..." policies from backup)

-- 3. Revert code changes in bank_account_service.dart
-- (Use git to revert to previous version)
```

---

## 📞 Support

If you encounter issues:
1. Check database logs in Supabase dashboard
2. Check application logs in Flutter console
3. Review `TRUSTED_PARTNER_SCHEMA_FIX.md` for detailed explanation
4. Check `IMPLEMENTATION_SUMMARY.md` for overview

---

## 🎉 Completion

Once all checklist items are complete:
1. Mark this migration as complete in your project notes
2. Update any team documentation
3. Monitor production for 24-48 hours to ensure stability
4. Consider removing `business_id` column entirely after confidence period

**Migration Date:** _________________
**Executed By:** _________________
**Verified By:** _________________
