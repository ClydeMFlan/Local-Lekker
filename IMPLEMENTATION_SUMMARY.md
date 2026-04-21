# Trusted Partner Database Schema Fix - Implementation Complete

## ✅ Files Created

1. **fix_trusted_partner_bank_accounts_schema.sql** - SQL migration script
2. **TRUSTED_PARTNER_SCHEMA_FIX.md** - Detailed documentation
3. This summary file

## ✅ Code Changes Made

### `lib/services/bank_account_service.dart`
- ✅ Changed `businessId` → `userId` in `BankAccount` class
- ✅ Updated `fromMap()` to use `user_id` field
- ✅ Updated `toMap()` to use `user_id` field
- ✅ Changed `saveBankAccount()` parameter from `businessId` to `userId`
- ✅ Updated `saveBankAccount()` to insert/update with `user_id`
- ✅ Renamed `getBusinessBankAccounts()` → `getUserBankAccounts()`
- ✅ Updated `getActiveBankAccount()` to use `userId`

---

## 📋 Implementation Steps

### Step 1: Run Database Migration
Execute the SQL migration script in Supabase SQL Editor:

```bash
# File: fix_trusted_partner_bank_accounts_schema.sql
```

This will:
1. Add `user_id` column to `trusted_partner_bank_accounts`
2. Migrate existing data from `business_id` to `user_id`
3. Update foreign key constraints
4. Create performance indexes

### Step 2: Update Application Code (ALREADY DONE ✅)
The Dart code has been updated to use `userId` instead of `businessId`.

### Step 3: Test the Changes
After running the migration, test these flows:

1. **New Trusted Partner Sign-Up**
   - Complete sign-up with DOB
   - Add bank account details
   - Verify bank account saves with `user_id`

2. **Existing Trusted Partners**
   - Login as existing trusted partner
   - View bank account details
   - Edit bank account details
   - Verify changes persist

3. **Payment Processing**
   - Test discount application
   - Verify bank account fetched correctly for payouts

---

## 🔍 Verification Queries

After running the migration, verify everything worked:

### Check all bank accounts have user_id
```sql
SELECT 
    tpba.id,
    tpba.user_id,
    tpba.account_holder_name,
    p.name,
    p.surname,
    p.email
FROM 
    trusted_partner_bank_accounts tpba
    JOIN profiles p ON tpba.user_id = p.id
WHERE 
    p.role = 'trusted_partner';
```

### Check for orphaned records
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

Should return 0 rows.

---

## 🎯 Benefits

1. ✅ **Simplified Architecture** - Direct user → bank account relationship
2. ✅ **No Business Dependency** - Trusted partners don't need to create a business record first
3. ✅ **Cleaner Sign-Up Flow** - Fewer tables, fewer potential errors
4. ✅ **Better Performance** - Fewer JOINs in queries
5. ✅ **Consistent Schema** - Matches `trusted_partner_discounts` pattern

---

## 🚨 Important Notes

### RLS Policies
After migration, verify/update RLS policies on `trusted_partner_bank_accounts`:

```sql
-- Allow trusted partners to view their own bank accounts
CREATE POLICY "Users can view own bank accounts"
ON trusted_partner_bank_accounts
FOR SELECT
USING (auth.uid() = user_id);

-- Allow trusted partners to insert their own bank accounts
CREATE POLICY "Users can insert own bank accounts"
ON trusted_partner_bank_accounts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Allow trusted partners to update their own bank accounts
CREATE POLICY "Users can update own bank accounts"
ON trusted_partner_bank_accounts
FOR UPDATE
USING (auth.uid() = user_id);
```

### Breaking Changes
⚠️ **This is a breaking change** for any code that:
- Calls `saveBankAccount(businessId: ...)` - Now requires `userId:`
- Calls `getBusinessBankAccounts()` - Now renamed to `getUserBankAccounts()`
- References `BankAccount.businessId` - Now `BankAccount.userId`

### Files That May Need Updates
Search your codebase for:
- `businessId` in bank account context
- `getBusinessBankAccounts`
- `business_id` in trusted_partner_bank_accounts queries

---

## 📝 Next Steps

1. ✅ Review this summary
2. ⏳ Run SQL migration in Supabase
3. ⏳ Test trusted partner sign-up flow
4. ⏳ Test existing trusted partners can view/edit bank details
5. ⏳ Update any other files that reference old `businessId` pattern
6. ⏳ Update RLS policies if needed
7. ⏳ Deploy to production

---

## 🔄 Rollback (If Needed)

If issues arise, rollback steps are in `TRUSTED_PARTNER_SCHEMA_FIX.md`.

---

## Questions?
Review `TRUSTED_PARTNER_SCHEMA_FIX.md` for detailed explanation and diagrams.
