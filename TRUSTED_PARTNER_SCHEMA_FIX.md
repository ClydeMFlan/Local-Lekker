# Trusted Partner Database Schema Fix - Summary

## Problem
The current schema links `trusted_partner_bank_accounts` to `businesses` via `business_id`, creating unnecessary complexity. The correct approach is to link directly to the user/profile.

## Solution
Change `trusted_partner_bank_accounts` to use `user_id` instead of `business_id`.

---

## Database Changes

### Before (Current Schema):
```
profiles (id) 
    ↓ (owner_member_id)
businesses (id)
    ↓ (business_id)
trusted_partner_bank_accounts
```

### After (Fixed Schema):
```
profiles (id)
    ↓ (user_id)
trusted_partner_bank_accounts
```

---

## Migration Steps

1. **Run SQL Migration**: Execute `fix_trusted_partner_bank_accounts_schema.sql`
   - Adds `user_id` column
   - Migrates existing data from `business_id` to `user_id`
   - Updates foreign key constraints
   - Creates performance indexes

2. **Update Dart Code**: 
   - `bank_account_service.dart` - Change `businessId` to `userId`
   - `business_profile_page.dart` - Pass `userId` instead of `businessId` when saving bank accounts

---

## Updated Schema

### `trusted_partner_bank_accounts` table (NEW)
```sql
CREATE TABLE public.trusted_partner_bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,  -- NEW: Direct link to user
  business_id uuid,       -- OPTIONAL: Keep for backward compatibility or remove
  account_holder_name text,
  bank_name text,
  account_type text CHECK (account_type = ANY (ARRAY['checking'::text, 'savings'::text])),
  account_number text,
  branch_code text,
  paystack_public_key text,
  paystack_secret_key text,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.trusted_partner_bank_accounts
  ADD CONSTRAINT trusted_partner_bank_accounts_user_id_fkey 
  FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
```

---

## Code Changes Required

### 1. `bank_account_service.dart`
- Change property from `businessId` to `userId`
- Update all references in queries

### 2. `business_profile_page.dart`
- Pass `user.id` instead of `businessId` when calling `BankAccountService.saveBankAccount()`

---

## Testing Checklist

After migration:

1. ✅ Run query to verify existing bank accounts have `user_id` populated
2. ✅ Test trusted partner sign-up flow - bank account should save with `user_id`
3. ✅ Test editing bank account details
4. ✅ Test fetching bank account for payment processing
5. ✅ Verify Paystack integration still works

---

## Rollback Plan

If something goes wrong, you can rollback:

```sql
-- Restore business_id as primary foreign key
ALTER TABLE public.trusted_partner_bank_accounts
DROP CONSTRAINT IF EXISTS trusted_partner_bank_accounts_user_id_fkey;

ALTER TABLE public.trusted_partner_bank_accounts
ADD CONSTRAINT trusted_partner_bank_accounts_business_id_fkey 
FOREIGN KEY (business_id) REFERENCES public.businesses(id);

-- Remove user_id column
ALTER TABLE public.trusted_partner_bank_accounts
DROP COLUMN user_id;
```

---

## Benefits

1. **Simpler architecture** - Direct user → bank account relationship
2. **No dependency on businesses table** - Trusted partners don't need to create a business record first
3. **Cleaner sign-up flow** - One less table to worry about during registration
4. **Better performance** - One less JOIN in queries
5. **Consistent with other tables** - `trusted_partner_discounts` already uses `trusted_partner_id` (user_id)
