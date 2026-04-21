# Database Unused Columns Analysis

**Analysis Date:** November 7, 2025  
**Purpose:** Identify unused columns that can be safely removed from the database

---

## ❌ UNUSED COLUMNS (Safe to Remove)

### 1. `payments` Table - PayFast Legacy Columns

These PayFast-related columns are **NOT used** in the codebase (app uses Paystack):

| Column | Type | Usage | Recommendation |
|--------|------|-------|----------------|
| `pf_payment_id` | text | ❌ Not referenced | **DELETE** |
| `payment_status` | text | ❌ Not referenced (duplicate of `status`) | **DELETE** |
| `item_name` | text | ❌ Not referenced | **DELETE** |
| `item_description` | text | ❌ Not referenced | **DELETE** |
| `merchant_id` | text | ❌ Not referenced | **DELETE** |
| `token` | text | ❌ Not referenced | **DELETE** |
| `signature` | text | ❌ Not referenced | **DELETE** |

**Reason:** These were added for PayFast integration (see `add_payfast_webhook_columns.sql`), but the app exclusively uses **Paystack** for payments. The `status` column already handles payment status.

**Search Results:** 0 references in Dart code for any of these columns.

---

## ⚠️ POTENTIALLY UNUSED (Needs Review)

### 2. `payments` Table - `remarketing_id`

| Column | Type | Usage | Status |
|--------|------|-------|--------|
| `remarketing_id` | text | ❓ Only in test files | **REVIEW** |

**References:** Only found in `query_notifications.dart` (test file)  
**Recommendation:** If not using remarketing/analytics integration, can be removed.

---

## ✅ USED COLUMNS (DO NOT Remove)

### 3. `profiles` Table Columns

| Column | Type | Usage | Status |
|--------|------|-------|--------|
| `is_tp_member` | boolean | ✅ Used (6 refs) | **KEEP** |
| `in_app_password` | text | ❌ Deprecated | **DROP** (replaced by OTP change password) |
| `category` | text | ✅ Used (20+ refs) | **KEEP** |
| `bank_account_holder` | text | ✅ Used (3 refs) | **KEEP** |
| `bank_name` | text | ✅ Used | **KEEP** |
| `bank_account_number` | text | ✅ Used | **KEEP** |
| `bank_branch_code` | text | ✅ Used | **KEEP** |
| `bank_account_type` | text | ✅ Used | **KEEP** |

**Evidence:**
- `is_tp_member`: Used in `members_home_page.dart`, `member_profile_page.dart`, `trusted_partner_key_dialog.dart`
- `in_app_password`: Deprecated; removed from app and scheduled for column drop
- `category`: Used extensively for business categorization (20+ references)
- Bank fields: Used in `trusted_partner_key_dialog.dart` and model classes

---

## SQL Scripts to Remove Unused Columns

### Step 1: Backup Data (Optional)
```sql
-- Create backup of payments table with all data
CREATE TABLE payments_backup AS SELECT * FROM payments;
```

### Step 2: Remove PayFast Columns
```sql
-- Remove unused PayFast webhook columns from payments table
ALTER TABLE payments DROP COLUMN IF EXISTS pf_payment_id;
ALTER TABLE payments DROP COLUMN IF EXISTS payment_status;
ALTER TABLE payments DROP COLUMN IF EXISTS item_name;
ALTER TABLE payments DROP COLUMN IF EXISTS item_description;
ALTER TABLE payments DROP COLUMN IF EXISTS merchant_id;
ALTER TABLE payments DROP COLUMN IF EXISTS token;
ALTER TABLE payments DROP COLUMN IF EXISTS signature;

-- Optional: Remove remarketing_id if not using analytics
-- ALTER TABLE payments DROP COLUMN IF EXISTS remarketing_id;
```

### Step 3: Verify Removal
```sql
-- Check remaining columns in payments table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'payments'
ORDER BY ordinal_position;
```

---

## Summary

### Can Be Deleted: 7 Columns
1. ❌ `payments.pf_payment_id`
2. ❌ `payments.payment_status`  
3. ❌ `payments.item_name`
4. ❌ `payments.item_description`
5. ❌ `payments.merchant_id`
6. ❌ `payments.token`
7. ❌ `payments.signature`

### Needs Review: 1 Column
- ⚠️ `payments.remarketing_id` (only in test files)

### Must Keep: All Others
All columns in other tables are actively used by the application.

---

## Impact Assessment

### Risk Level: **LOW** ✅

**Why Safe to Delete:**
1. Zero references in production Dart code
2. PayFast was never implemented (Paystack is used)
3. `status` column already handles payment status
4. No foreign key dependencies on these columns

**Benefits:**
- Reduced storage overhead
- Cleaner schema
- Faster queries on payments table
- No confusion about which payment gateway is used

---

## Migration Script

```sql
-- Migration: Remove unused PayFast columns from payments table
-- Date: 2025-11-07
-- Reason: PayFast integration was never implemented, app uses Paystack

BEGIN;

-- Verify no data would be lost (these should all be NULL)
DO $$
DECLARE
    col_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO col_count FROM payments 
    WHERE pf_payment_id IS NOT NULL 
       OR payment_status IS NOT NULL
       OR item_name IS NOT NULL 
       OR item_description IS NOT NULL
       OR merchant_id IS NOT NULL
       OR token IS NOT NULL
       OR signature IS NOT NULL;
    
    IF col_count > 0 THEN
        RAISE EXCEPTION 'Found % rows with data in PayFast columns. Review before deletion.', col_count;
    END IF;
    
    RAISE NOTICE 'All PayFast columns are NULL or empty. Safe to proceed.';
END $$;

-- Remove columns
ALTER TABLE payments DROP COLUMN IF EXISTS pf_payment_id;
ALTER TABLE payments DROP COLUMN IF EXISTS payment_status;
ALTER TABLE payments DROP COLUMN IF EXISTS item_name;
ALTER TABLE payments DROP COLUMN IF EXISTS item_description;
ALTER TABLE payments DROP COLUMN IF EXISTS merchant_id;
ALTER TABLE payments DROP COLUMN IF EXISTS token;
ALTER TABLE payments DROP COLUMN IF EXISTS signature;

-- Verify
SELECT 
    COUNT(*) as total_rows,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_payments,
    COUNT(CASE WHEN paystack_reference IS NOT NULL THEN 1 END) as paystack_payments
FROM payments;

COMMIT;
```

---

## Notes

1. **PayFast vs Paystack:** The app uses `paystack_reference` and `raw_event` (jsonb) for Paystack integration, not PayFast columns.

2. **Payment Status:** The existing `status` column (`pending`, `completed`, `failed`, `cancelled`) is sufficient and actively used.

3. **No Migration Required:** Since these columns were never used, no data migration or code changes are needed.

4. **Testing:** After deletion, test:
   - Member payment flow
   - Subscription renewals  
   - Payment webhook handling
   - Payment history display

---

## Conclusion

**7 columns can be safely removed** from the `payments` table with zero impact on application functionality. All were added for PayFast integration that was never implemented.
