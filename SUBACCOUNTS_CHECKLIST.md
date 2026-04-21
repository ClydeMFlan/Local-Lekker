# Paystack Subaccounts - Implementation Checklist

## ✅ Completed

### 1. Core Service Implementation
- [x] Added `createSubaccount()` method to PaystackService
- [x] Added `updateSubaccount()` method to PaystackService
- [x] Added `getSubaccount()` method to PaystackService
- [x] Enhanced `startOneTimePayment()` to accept `subaccountCode` parameter

### 2. Database Schema
- [x] Created migration file `add_paystack_subaccounts.sql`
- [x] Added columns to `trusted_partner_bank_accounts`:
  - `subaccount_code` (TEXT)
  - `percentage_charge` (NUMERIC, default 90.0)
  - `subaccount_created_at` (TIMESTAMP)
  - `subaccount_active` (BOOLEAN, default true)
- [x] Added database index on `subaccount_code`
- [x] Added column comments for documentation

### 3. Business Profile Integration
- [x] Updated `business_profile_page.dart` `_saveBankingDetails()` method
- [x] Added subaccount creation after recipient code creation
- [x] Store subaccount code in database with banking details
- [x] Set `subaccount_active` flag based on creation success
- [x] Handle subaccount creation failures gracefully

### 4. Payment Flow Integration
- [x] Updated `deal_approval_popup_service.dart` `_processPaystackPayment()` method
- [x] Fetch subaccount code from `trusted_partner_bank_accounts` table
- [x] Check `subaccount_active` flag before using
- [x] Pass subaccount code to payment initialization
- [x] Log subaccount usage for debugging

### 5. Documentation
- [x] Created comprehensive implementation guide (`PAYSTACK_SUBACCOUNTS_IMPLEMENTATION.md`)
- [x] Documented architecture and flow
- [x] Added API reference
- [x] Included troubleshooting guide
- [x] Listed benefits vs. Option A (transfers)

## 🔄 Pending - Database Migration

### Run SQL Migration
```bash
# Connect to your Supabase database
psql -h db.qdrotavcmmevhgveodcp.supabase.co -d postgres -U postgres

# Or via Supabase Dashboard:
# 1. Go to Supabase Dashboard
# 2. Select your project
# 3. Go to SQL Editor
# 4. Copy contents of add_paystack_subaccounts.sql
# 5. Execute the script
```

**Migration File**: `add_paystack_subaccounts.sql`

## 🔄 Pending - Testing

### 1. Trusted Partner Setup
- [ ] Login as existing trusted partner (Momsie)
- [ ] Navigate to Business Profile → Banking Details
- [ ] Click "Edit Banking Details"
- [ ] Verify form loads with existing data
- [ ] Save details to trigger subaccount creation
- [ ] Check logs for subaccount creation success
- [ ] Verify database has `subaccount_code` populated

### 2. Database Verification
```sql
-- Check if subaccount was created
SELECT 
  businesses.name AS business_name,
  tp.account_holder_name,
  tp.bank_name,
  tp.subaccount_code,
  tp.percentage_charge,
  tp.subaccount_active,
  tp.subaccount_created_at,
  tp.paystack_recipient_code
FROM trusted_partner_bank_accounts tp
JOIN businesses ON businesses.id = tp.business_id
WHERE businesses.name = 'Momsie';
```

### 3. Payment Flow Test
- [ ] Login as member
- [ ] Select weight-based deal (e.g., 100g steak at R10.50)
- [ ] Request deal authorization
- [ ] Login as trusted partner and approve
- [ ] Login as member and click "Pay"
- [ ] Verify payment confirmation dialog shows business name
- [ ] Check console logs for subaccount code being fetched
- [ ] Proceed with payment
- [ ] Complete payment in Paystack WebView
- [ ] Verify payment success

### 4. Paystack Dashboard Verification
- [ ] Login to Paystack Dashboard (https://dashboard.paystack.com)
- [ ] Navigate to Subaccounts section
- [ ] Verify new subaccount appears with business name
- [ ] Check subaccount details (bank account, percentage)
- [ ] Navigate to Transactions
- [ ] Find the test payment transaction
- [ ] Verify it shows subaccount split
- [ ] Check partner settlement schedule

### 5. Edge Case Testing
- [ ] Test payment for partner WITHOUT subaccount (should work, no split)
- [ ] Test subaccount creation with invalid bank code (should fail gracefully)
- [ ] Test subaccount creation with wrong account number (should fail gracefully)
- [ ] Test payment with `subaccount_active = false` (should ignore subaccount)

## 🔄 Pending - Partner Onboarding

### Notify Existing Partners
- [ ] Email existing trusted partners about new feature
- [ ] Explain split payment benefits
- [ ] Request they update banking details to enable feature
- [ ] Provide instructions for Business Profile → Banking Details

### Email Template
```
Subject: New Feature: Automatic Payment Splits

Hi [Partner Name],

We've upgraded our payment system! Now when members pay for deals, you'll receive your share (90%) automatically and directly from Paystack.

To enable this feature:
1. Login to Local Lekker app
2. Go to Business Profile
3. Click "Edit Banking Details"
4. Re-enter your banking information (even if already saved)
5. Save

Benefits:
- Faster payment receipt
- Automatic 90/10 split (you get 90%)
- Reduced manual processing
- Direct settlement to your bank account

Questions? Reply to this email.

Thanks,
Local Lekker Team
```

## 🔄 Pending - Monitoring Setup

### Create Admin Dashboard Queries
Add to admin panel:
```sql
-- Active subaccounts count
SELECT COUNT(*) 
FROM trusted_partner_bank_accounts 
WHERE subaccount_active = true;

-- Recent subaccount creations
SELECT 
  businesses.name,
  tp.subaccount_code,
  tp.subaccount_created_at
FROM trusted_partner_bank_accounts tp
JOIN businesses ON businesses.id = tp.business_id
WHERE tp.subaccount_created_at > NOW() - INTERVAL '7 days'
ORDER BY tp.subaccount_created_at DESC;

-- Partners without subaccounts
SELECT 
  businesses.name,
  tp.paystack_recipient_code,
  tp.subaccount_code IS NULL AS missing_subaccount
FROM trusted_partner_bank_accounts tp
JOIN businesses ON businesses.id = tp.business_id
WHERE tp.subaccount_code IS NULL 
  AND tp.is_active = true;
```

## 🔄 Optional Enhancements

### UI Improvements
- [ ] Add "Split Payments Enabled" badge to Business Profile
- [ ] Show split percentage in Banking Details section
- [ ] Add tooltip explaining subaccounts to partners
- [ ] Display last settlement date from Paystack

### Partner Analytics
- [ ] Create screen showing partner's settlement history
- [ ] Display pending settlements
- [ ] Show split transactions breakdown
- [ ] Add CSV export for accounting

### Admin Tools
- [ ] Admin page to view all subaccounts
- [ ] Ability to enable/disable subaccount splits
- [ ] Bulk partner onboarding tool
- [ ] Subaccount health monitoring (failed settlements, etc.)

### Error Recovery
- [ ] Retry failed subaccount creations
- [ ] Alert admin when subaccount creation fails
- [ ] Automated testing of subaccount validity
- [ ] Quarterly subaccount verification job

## 📋 Rollback Plan

If subaccounts cause issues:

### Quick Disable
```sql
-- Disable all subaccounts (payments revert to platform account)
UPDATE trusted_partner_bank_accounts 
SET subaccount_active = false;
```

### Code Rollback
1. Remove `subaccountCode` parameter from payment calls
2. Redeploy app
3. Subaccount data remains in database for future re-enable

### Full Rollback
1. Run SQL to remove columns:
```sql
ALTER TABLE trusted_partner_bank_accounts 
DROP COLUMN IF EXISTS subaccount_code,
DROP COLUMN IF EXISTS percentage_charge,
DROP COLUMN IF EXISTS subaccount_created_at,
DROP COLUMN IF EXISTS subaccount_active;
```
2. Revert code changes in git
3. Implement Option A (transfers) instead

## 🎯 Success Metrics

Track these KPIs:
- [ ] % of partners with active subaccounts
- [ ] Average time from payment to partner settlement
- [ ] Failed subaccount creation rate
- [ ] Partner satisfaction with payment speed
- [ ] Reduction in manual transfer requests

## 📞 Support Contacts

- **Paystack Support**: support@paystack.com
- **Paystack Docs**: https://paystack.com/docs
- **Local Lekker Dev**: [Your contact]

## Notes

- Subaccounts require business verification on Paystack
- Bank codes must match Paystack's codes exactly
- Settlement timing controlled by Paystack (typically T+1 or T+2 days)
- Transaction fees charged to platform account
- Partners see settlements as "PAYSTACK/Local Lekker" on statements
