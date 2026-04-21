# Data Population Issues Analysis

## Summary
Based on the database analysis, we've identified critical data population issues in the `deal_receipts` and `virtual_receipts` tables that are causing the receipt generation to fail.

## Key Findings

### 1. Missing Denormalized Data in `deal_receipts`
The `deal_receipts` table has columns for denormalized data that should be populated when a receipt is created:
- `business_name` - Name of the business (from businesses table)
- `discount_name` - Name of the discount (from trusted_partner_discounts table)
- `member_name` - Full name of the member (from profiles table)
- `member_email` - Email of the member (from profiles table)

**Problem**: These fields are likely NULL in existing records because they weren't populated during receipt creation.

### 2. Missing `receipt_data` in `virtual_receipts`
The `virtual_receipts` table has a `receipt_data` JSONB column that should contain:
```json
{
  "business_name": "...",
  "member_name": "...",
  "member_email": "...",
  "amount": "...",
  "discount_name": "...",
  "payment_method": "...",
  "receipt_number": "...",
  "date": "..."
}
```

**Problem**: This JSONB field may be NULL or incomplete in existing records.

### 3. Schema Discrepancies
The actual database schema differs from what was expected:
- `deal_authorizations` has `approved_at` (not `authorized_at`)
- `deal_authorizations` may have `payment_completed_at` (added via migration)
- `businesses` table has `contact_email` and `contact_number` (not `email` and `phone`)
- `profiles` table has `contact` (not `phone`)
- `virtual_receipts` doesn't have `updated_at` column

## Root Cause
The receipt generation functions in the Edge Functions are likely not properly populating these denormalized fields when creating receipts. This causes:
1. NULL values in critical display fields
2. Incomplete receipt data for PDF generation
3. Missing information for receipt display in the app

## Recommended Fixes

### Fix 1: Update Receipt Creation Logic
Modify the Edge Function that creates receipts to properly populate all denormalized fields:

```typescript
// In the receipt creation function
const dealReceipt = await supabase
  .from('deal_receipts')
  .insert({
    deal_authorization_id: authId,
    member_id: authorization.member_id,
    trusted_partner_id: authorization.trusted_partner_id,
    business_id: authorization.business_id,
    receipt_number: generateReceiptNumber(),
    amount: authorization.amount,
    payment_method: paymentMethod,
    // CRITICAL: Populate these denormalized fields
    business_name: business.name,
    discount_name: discount.name,
    member_name: `${profile.name} ${profile.surname}`,
    member_email: profile.email
  });

const virtualReceipt = await supabase
  .from('virtual_receipts')
  .insert({
    deal_authorization_id: authId,
    receipt_number: receiptNumber,
    qr_code: qrCodeData,
    // CRITICAL: Populate receipt_data JSONB
    receipt_data: {
      business_name: business.name,
      member_name: `${profile.name} ${profile.surname}`,
      member_email: profile.email,
      amount: authorization.amount,
      discount_name: discount.name,
      payment_method: paymentMethod,
      receipt_number: receiptNumber,
      date: new Date().toISOString()
    }
  });
```

### Fix 2: Backfill Existing Records
Create a migration script to populate missing data in existing records:

```sql
-- Backfill deal_receipts with missing denormalized data
UPDATE deal_receipts dr
SET 
  business_name = b.name,
  discount_name = tpd.name,
  member_name = p.name || ' ' || p.surname,
  member_email = p.email
FROM deal_authorizations da
JOIN businesses b ON da.business_id = b.id
JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
JOIN profiles p ON da.member_id = p.id
WHERE dr.deal_authorization_id = da.id
  AND (dr.business_name IS NULL 
    OR dr.discount_name IS NULL 
    OR dr.member_name IS NULL 
    OR dr.member_email IS NULL);

-- Backfill virtual_receipts with missing receipt_data
UPDATE virtual_receipts vr
SET receipt_data = jsonb_build_object(
  'business_name', b.name,
  'member_name', p.name || ' ' || p.surname,
  'member_email', p.email,
  'amount', da.amount::text,
  'discount_name', tpd.name,
  'payment_method', dr.payment_method,
  'receipt_number', vr.receipt_number,
  'date', vr.created_at::text
)
FROM deal_authorizations da
JOIN deal_receipts dr ON dr.deal_authorization_id = da.id
JOIN businesses b ON da.business_id = b.id
JOIN trusted_partner_discounts tpd ON da.discount_id = tpd.id
JOIN profiles p ON da.member_id = p.id
WHERE vr.deal_authorization_id = da.id
  AND (vr.receipt_data IS NULL OR vr.receipt_data = '{}'::jsonb);
```

### Fix 3: Add Database Constraints
Add NOT NULL constraints to prevent future issues:

```sql
-- Make critical fields NOT NULL (after backfilling)
ALTER TABLE deal_receipts 
  ALTER COLUMN business_name SET NOT NULL,
  ALTER COLUMN discount_name SET NOT NULL,
  ALTER COLUMN member_name SET NOT NULL,
  ALTER COLUMN member_email SET NOT NULL;

ALTER TABLE virtual_receipts
  ALTER COLUMN receipt_data SET NOT NULL;
```

## Next Steps
1. Review the Edge Functions that create receipts
2. Update them to populate all denormalized fields
3. Run the backfill migration on existing data
4. Add NOT NULL constraints to prevent future issues
5. Test receipt generation end-to-end
