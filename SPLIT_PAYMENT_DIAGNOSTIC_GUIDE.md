# Split Payment Diagnostic Guide

## Current Status
- ✅ Database: Banking row exists with active subaccount (ACCT_zdl6gqiijucnsud)
- ✅ Database: All deals linked to partner with subaccount
- ❌ Paystack: No transactions showing for partner subaccount
- **Root Cause**: Subaccount not being included in payment initialization

## Changes Made
1. Added ZAR currency to transaction init
2. Added blocking logic to prevent payments without subaccount
3. Enhanced logging in paystack_service.dart
4. Updated deal_payment_webview_page.dart to query banking table

## Testing Steps

### 1. Hot Reload App
```bash
flutter run
```

### 2. Initiate Test Payment
- Log in as a member
- Authorize a deal for partner "Momsies" (user_id: 78e67dc8-583b-4fe0-84e6-aa4d0c55a92e)
- Watch terminal output

### 3. Check Terminal Logs

**Expected logs if working correctly:**
```
💳 Fetching partner subaccount for split payment...
💳 Found active subaccount for partner: ACCT_zdl6gqiijucnsud
✅ SUBACCOUNT INCLUDED: ACCT_zdl6gqiijucnsud
🔍 PAYSTACK INIT PAYLOAD: {"email":"...","amount":...,"subaccount":"ACCT_zdl6gqiijucnsud","currency":"ZAR",...}
✅ Paystack transaction initialized - Auth URL: https://...
```

**If subaccount lookup fails:**
```
💳 Fetching partner subaccount for split payment...
⚠️ No active subaccount found for partner
🚫 No active subaccount found — blocking payment to avoid routing to platform account
```

**If payment proceeds without subaccount:**
```
⚠️ NO SUBACCOUNT - Payment routing to platform account!
🔍 PAYSTACK INIT PAYLOAD: {"email":"...","amount":...,"currency":"ZAR",...}
(no "subaccount" field in payload)
```

### 4. Paystack Dashboard Verification
After successful payment:
- Go to Paystack Dashboard → Transactions
- Search for the transaction reference (shown in logs as `one_time_...`)
- Check transaction details:
  - **Subaccount**: Should show ACCT_zdl6gqiijucnsud
  - **Split**: Should show 90% to partner, 10% to platform

### 5. Alternative: Check by Subaccount Filter
- Paystack Dashboard → Subaccounts
- Click on "Momsies" subaccount
- View transactions tab
- Should now show payments

## Troubleshooting

### No logs appear for subaccount lookup
**Issue**: Deal authorization flow not using updated code
**Fix**: Confirm you're testing the deal payment flow (not bill payment or other flows)

### Subaccount lookup returns null despite DB having data
**Possible causes**:
1. **RLS policy blocking query**: Check if member role can read trusted_partner_bank_accounts
   ```sql
   -- Run as your test member user
   SELECT subaccount_code FROM trusted_partner_bank_accounts 
   WHERE user_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e' AND is_active = TRUE;
   ```
2. **Wrong trusted_partner_id on deal**: Verify deal has correct partner ID
   ```sql
   SELECT id, trusted_partner_id FROM deal_authorizations 
   WHERE id = 'DEAL_ID_FROM_TEST';
   ```

### Payment proceeds but Paystack strips subaccount
**Possible causes**:
1. **Subaccount inactive in Paystack**: Check Paystack dashboard subaccount status
2. **Currency mismatch**: Ensure subaccount bank is ZAR-compatible
3. **Paystack API validation error**: Check response body for warnings

### Payment blocked with "No active subaccount found"
**Good**: Blocking logic working as intended
**Action**: Investigate why DB query returns null (see RLS/query troubleshooting above)

## SQL Queries for Debugging

### Verify banking row exists
```sql
SELECT user_id, bank_name, subaccount_code, subaccount_active, is_active
FROM trusted_partner_bank_accounts
WHERE user_id = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';
```

### Check deal has correct partner ID
```sql
SELECT da.id, da.trusted_partner_id, b.subaccount_code
FROM deal_authorizations da
LEFT JOIN trusted_partner_bank_accounts b 
  ON b.user_id = da.trusted_partner_id AND b.is_active = TRUE
WHERE da.id = 'YOUR_TEST_DEAL_ID';
```

### Find partners missing subaccounts
```sql
SELECT tp.user_id, tp.unique_key, b.subaccount_code, b.subaccount_active
FROM trusted_partners tp
LEFT JOIN trusted_partner_bank_accounts b 
  ON b.user_id = tp.user_id AND b.is_active = TRUE
WHERE b.subaccount_code IS NULL OR b.subaccount_active IS NOT TRUE;
```

## Next Steps Based on Logs

| Log Output | Diagnosis | Action |
|------------|-----------|--------|
| "Found active subaccount" + payload shows subaccount | ✅ Code working | Check Paystack dashboard transaction details |
| "No active subaccount found" + payment blocked | ⚠️ Query failing | Check RLS policies and deal.trusted_partner_id |
| "NO SUBACCOUNT" + payment proceeds | ❌ Logic bypassed | Check if different payment flow used |
| No logs at all | ❌ Code not running | Verify app reloaded, check payment entry point |

## Key Files
- `lib/services/paystack_service.dart` - Transaction initialization
- `lib/services/deal_approval_popup_service.dart` - Subaccount lookup for deals
- `lib/features/business/bill_approval_page.dart` - Subaccount lookup for bills
- `lib/features/payments/deal_payment_webview_page.dart` - Post-payment verification

## Expected Behavior
- ✅ Payment initialization includes subaccount parameter
- ✅ Paystack transaction shows split details
- ✅ Partner sees payment in their Paystack subaccount dashboard
- ✅ Platform account only receives 10% (transaction fee)
- ✅ Partner account receives 90% settlement

## Contact Points
- Paystack dashboard: https://dashboard.paystack.com
- Supabase SQL Editor: https://supabase.com/dashboard/project/.../sql
- Test member email: (your test member account)
- Test partner: Momsies (78e67dc8-583b-4fe0-84e6-aa4d0c55a92e)
