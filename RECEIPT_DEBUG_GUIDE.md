# Receipt Auto-Generation Debugging Guide

## Issue
Member completes payment but receipt doesn't appear in:
- Member's "My Receipts" page
- Trusted Partner's "Receipts" tab

Trusted partner still sees "Waiting for member to complete payment" instead of "In-app payment received"

## Changes Made

### 1. Fixed Approved Tab Status Display
**File**: `lib/features/auth/deal_authorization_dashboard.dart`
**Method**: `_buildApprovedActions()` (Lines ~605-650)

**Before**:
```dart
// Always showed: "Waiting for member to complete payment"
```

**After**:
```dart
if (paymentCompleted) {
  // Show: "In-app payment received. Receipt generated automatically."
  // Green checkmark icon
} else {
  // Show: "Waiting for member to complete payment"
  // Orange hourglass icon
}
```

### 2. Enhanced Receipt Auto-Generation Logging
**File**: `lib/features/payments/deal_payment_webview_page.dart`
**Method**: `_autoGenerateReceipt()` (Lines ~124-270)

**Added detailed logging at each step**:
- Step 1: Fetching deal authorization data
- Step 2: Data fetched successfully
- Step 3: Generating sequential receipt number
- Step 4: Receipt data prepared
- Step 5: Inserting into virtual_receipts
- Step 6: Inserting into deal_receipts
- ✅ Success or ❌ Error with full details

**Log markers**:
- 🧾 = Receipt generation step
- ✅ = Success
- ❌ = Error
- ⚠️ = Warning

## Testing Steps

### Test the Complete Flow:

1. **Member**: Request a deal with in-app payment
2. **Trusted Partner**: Approve the deal in Pending tab
3. **Member**: Complete payment via Paystack
4. **Member**: Click "Return to Home" button
5. **Check logs** for receipt generation

### Expected Logs After "Return to Home":

```
🧾 ========================================
🧾 AUTO-GENERATE RECEIPT START
🧾 Deal ID: [deal-id]
🧾 ========================================
🧾 Step 1: Fetching deal authorization data...
🧾 Step 2: Deal data fetched successfully
🧾 Business ID: [business-id]
🧾 Member: [name] [surname]
🧾 Business: [business-name]
🧾 Discount: [discount-name]
🧾 Step 3: Generating sequential receipt number...
🧾 ✅ Sequential receipt number: TP-MOM-00XXX
🧾 Step 4: Receipt data prepared
🧾 Step 5: Inserting into virtual_receipts table...
✅ Virtual receipt ID: [id]
🧾 Step 6: Inserting into deal_receipts table...
✅ Deal receipt created successfully
🧾 ========================================
🧾 ✅ RECEIPT AUTO-GENERATION COMPLETE
🧾 Receipt Number: TP-MOM-00XXX
🧾 Deal ID: [deal-id]
🧾 ========================================
```

### If Receipt Generation Fails:

```
❌ ========================================
❌ RECEIPT AUTO-GENERATION FAILED
❌ Deal ID: [deal-id]
❌ Error: [error message]
❌ Stack trace: [full stack trace]
❌ ========================================
```

## Debugging with SQL

Run queries in `debug_receipt_generation.sql` to check:

1. **Check if payment_completed_at is set**:
   ```sql
   SELECT id, payment_completed_at, status
   FROM deal_authorizations
   WHERE id = '[deal-id]';
   ```

2. **Check if virtual_receipts was created**:
   ```sql
   SELECT * FROM virtual_receipts
   WHERE deal_authorization_id = '[deal-id]';
   ```

3. **Check if deal_receipts was created**:
   ```sql
   SELECT * FROM deal_receipts
   WHERE deal_authorization_id = '[deal-id]';
   ```

4. **Check RLS policies**:
   ```sql
   -- Make sure INSERT policies exist for both tables
   SELECT * FROM pg_policies
   WHERE tablename IN ('virtual_receipts', 'deal_receipts')
   AND cmd = 'INSERT';
   ```

## Common Issues & Solutions

### Issue 1: No logs appear
**Cause**: `_handleManualReturn()` not being called
**Solution**: Make sure user clicks "Return to Home" button after payment

### Issue 2: "business_id is null" error
**Cause**: Discount data not fetched correctly
**Solution**: Check that `trusted_partner_discounts` has `business_id` field

### Issue 3: RLS policy violation
**Cause**: Missing INSERT policy or incorrect user context
**Solution**: 
- Verify `virtual_receipts` has INSERT policy for members
- Verify `deal_receipts` has INSERT policy for trusted partners
- Check that member is authenticated during receipt generation

### Issue 4: Sequential numbering fails
**Cause**: `get_next_receipt_number()` function not found or business doesn't exist
**Solution**:
- Verify SQL function exists in database
- Falls back to timestamp-based numbering (RCP-XXXXXXXXXXXX)

### Issue 5: Receipt created but not visible
**Cause**: Dashboard not refreshing or RLS SELECT policy issue
**Solution**:
- Pull to refresh on Receipts tab
- Check SELECT RLS policies on both tables

## Verification Checklist

After payment completion:

- [ ] Terminal shows "🧾 AUTO-GENERATE RECEIPT START"
- [ ] Terminal shows "✅ Virtual receipt ID: [id]"
- [ ] Terminal shows "✅ Deal receipt created successfully"
- [ ] Terminal shows "🧾 ✅ RECEIPT AUTO-GENERATION COMPLETE"
- [ ] Member's "My Receipts" page shows new receipt
- [ ] Trusted Partner's "Receipts" tab shows new receipt
- [ ] Trusted Partner's Approved tab shows "In-app payment received" (green checkmark)
- [ ] Receipt number is sequential: TP-MOM-00XXX

## Next Steps

1. **Hot reload** the app to apply changes
2. **Test the flow** with a new payment
3. **Monitor terminal output** for detailed logs
4. **Run SQL queries** from `debug_receipt_generation.sql` to verify database state
5. **Check RLS policies** if receipt creation fails

## Files Modified

- `lib/features/auth/deal_authorization_dashboard.dart` - Fixed status display
- `lib/features/payments/deal_payment_webview_page.dart` - Enhanced logging
- `debug_receipt_generation.sql` - NEW debugging queries

## Expected Behavior

**After successful payment**:
1. ✅ `payment_completed_at` timestamp is set in `deal_authorizations`
2. ✅ Receipt is auto-generated in both tables
3. ✅ Member sees receipt in "My Receipts"
4. ✅ Trusted Partner sees receipt in "Receipts" tab
5. ✅ Trusted Partner sees "In-app payment received" in Approved tab
6. ✅ Sequential receipt number (TP-PREFIX-XXXXX format)

---

**Status**: Ready for testing with enhanced logging
**Priority**: Check terminal logs after next payment to identify exact failure point
