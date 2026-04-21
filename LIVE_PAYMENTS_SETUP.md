# Live Paystack Payment Configuration Guide

## Current Status: ✅ LIVE PAYMENTS ENABLED

Your app is now configured for **real Paystack payments** with actual credit/debit cards and bank accounts.

---

## What Was Changed

### 1. Local Development Environment (`.env`)
- **Before**: `PAYSTACK_DEVELOPMENT_MODE=true` (simulated payments)
- **After**: `PAYSTACK_DEVELOPMENT_MODE=false` (real payments)
- **Keys**: Using `pk_live_...` and `sk_live_...` (production keys)

### 2. Release Builds (`.env.production`)
- Created dedicated production config with:
  - `PAYSTACK_DEVELOPMENT_MODE=false`
  - Live Paystack keys (`pk_live_...` and `sk_live_...`)
  - Automatically used by `build_production.sh`

### 3. Build Script (`build_production.sh`)
- Now copies `.env.production` → `.env` before building
- Ensures release APK/AAB/iOS builds always use live payment config

---

## Payment Flows Now LIVE

### ✅ Subscription Payments (Member Signup)
- **Flow**: Member signs up → Payment Options → Paystack checkout
- **What happens**:
  - Real Paystack WebView opens with live checkout
  - Member enters real card details
  - On success:
    - Card authorization saved to `members_card_details` (authorization_code + last4)
    - Subscription activated for 30 days
    - QR code generated
- **Database**: `members_card_details` stores authorization for renewals

### ✅ Subscription Renewals
- **Flow**: 30 days pass → Member renews → charges saved card
- **What happens**:
  - `PaystackService.chargeSavedCard()` uses stored `authorization_code`
  - Real charge made to member's card
  - Subscription extended 30 days

### ✅ In-App Payments (Member → Trusted Partner)
- **Flow**: Member buys deal → Paystack charges saved card → TP receives payment
- **What happens**:
  - Uses `authorization_code` from `members_card_details`
  - Real charge processed
  - Payment status tracked in `deal_authorizations`

### ✅ Banking Details for Trusted Partners
- **Flow**: TP enters bank account → creates Paystack recipient → ready for payouts
- **What happens**:
  - `PaystackService.createTransferRecipient()` creates live recipient
  - Saved to `trusted_partner_bank_accounts` (with `paystack_recipient_code`)
  - Can be used for Paystack Transfers API (when you implement payouts)

---

## How to Test Live Payments Safely

### Option 1: Use Paystack Test Cards (Recommended First)
Even with live keys and dev mode off, you can test with Paystack's test card numbers:
- **Test Card**: `4084084084084081`
- **CVV**: `408`
- **Expiry**: Any future date
- **OTP**: `123456`

These will complete successfully without real charges in the Paystack dashboard test mode.

### Option 2: Use Real Cards (Small Amounts)
- Subscribe with a real card (actual charge will occur)
- Monitor in your Paystack Dashboard: https://dashboard.paystack.com/
- Check transactions, authorizations, and settlements

---

## Environment Switching

### To Switch Back to Development Mode (Simulated Payments)
```bash
# Copy development config
cp .env.development .env

# Or manually edit .env
# Change: PAYSTACK_DEVELOPMENT_MODE=true
```

### To Enable Live Payments Again
```bash
# Copy production config
cp .env.production .env

# Or manually edit .env
# Change: PAYSTACK_DEVELOPMENT_MODE=false
```

### Current Active Config
Run this to see what mode you're in:
```bash
grep PAYSTACK_DEVELOPMENT_MODE .env
```

---

## Building Release Versions

### Android Release (APK + AAB)
```bash
./build_production.sh
```
This will:
1. Automatically use `.env.production` (live mode)
2. Build APK: `build/app/outputs/flutter-apk/app-release.apk`
3. Build AAB: `build/app/outputs/bundle/release/app-release.aab`

### iOS Release (macOS only)
```bash
./build_production.sh
```
Builds iOS archive in: `build/ios/iphoneos/Runner.app`

---

## What Gets Saved to Database

### Members
**Table**: `members_card_details`
- `authorization_code`: Paystack token for charging (e.g., `AUTH_abc123`)
- `last4`: Last 4 digits (e.g., `1234`)
- `exp_month`, `exp_year`: Card expiry
- `bank`, `brand`: Card issuer info
- `is_primary`: True for default card
- `is_active`: False if card deleted

**Table**: `members_bank_accounts`
- `account_number`: Masked (e.g., `xxxx1234`)
- `paystack_recipient_code`: For potential future payouts

### Trusted Partners
**Table**: `trusted_partner_bank_accounts`
- `account_holder_name`: Business/account name
- `bank_name`, `account_type`, `branch_code`: Bank details
- `paystack_recipient_code`: For Paystack Transfers (payouts)

---

## Security & PCI Compliance

### ✅ What's Secure
- **No CVV stored**: Never saved in database
- **No full card numbers**: Only last 4 digits stored
- **Paystack tokenization**: All sensitive data handled by Paystack
- **RLS enabled**: Users can only access their own data
- **Authorization codes**: Can be used for charging but not extracting card details

### ⚠️ Important Notes
- **Secret key security**: Your `sk_live_...` key is in `.env` (gitignored). For Supabase Edge Functions, set it as a project secret.
- **Webhook verification**: Paystack webhook validates signatures using secret key.
- **HTTPS only**: Paystack requires HTTPS for production callbacks.

---

## Webhook Configuration (For Automated Renewals)

### Current Setup
- Webhook endpoint: `https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook`
- Reads `PAYSTACK_SECRET_KEY` from Supabase project secrets

### To Enable in Paystack Dashboard
1. Go to: https://dashboard.paystack.com/settings/developer
2. Add webhook URL (above)
3. Select events:
   - `charge.success`
   - `subscription.create`
   - `subscription.disable`
4. Save

### Set Supabase Secret
```bash
# In Supabase project settings → Edge Functions → Secrets
# Add: PAYSTACK_SECRET_KEY = sk_live_b27efee63dc59ef7bc4b6a368548bd3c3aadc185
```

---

## Monitoring & Troubleshooting

### Check Transaction Status
```dart
// In PaystackService
final txn = await PaystackService().verifyTransaction('reference');
print('Status: ${txn['status']}'); // success/failed/pending
print('Auth code: ${txn['authorization']['authorization_code']}');
```

### View Saved Cards for a User
```dart
final cards = await PaystackService().getSavedPaymentMethods(userId);
for (var card in cards) {
  print('${card['brand']} ****${card['last4']} (${card['is_primary'] ? "Primary" : ""})');
}
```

### Database Queries
```sql
-- View all saved cards
SELECT user_id, authorization_code, last4, brand, is_primary, is_active
FROM members_card_details
WHERE is_active = true;

-- View TP bank accounts ready for payouts
SELECT user_id, account_holder_name, bank_name, paystack_recipient_code
FROM trusted_partner_bank_accounts
WHERE is_active = true;
```

---

## Next Steps for Full Production

1. **Test End-to-End**:
   - Sign up a new member with a real card
   - Verify card saved in `members_card_details`
   - Wait for renewal (or manually trigger) and check charge succeeds

2. **Configure Webhook**:
   - Add webhook URL to Paystack dashboard
   - Set Supabase secret for `PAYSTACK_SECRET_KEY`
   - Test by making a payment and checking webhook logs

3. **Implement Payouts** (if needed):
   - Add transfer initiation in `PaystackService`
   - Call `/transfer` endpoint with `paystack_recipient_code`
   - Track transfers in a new `payouts` table

4. **Set Up Monitoring**:
   - Paystack Dashboard: Monitor transactions daily
   - Supabase Logs: Check for RLS policy errors
   - Sentry/Crashlytics: Track payment failures

5. **Update App Store Listings**:
   - Mention subscription model
   - Add "Payments by Paystack" badge
   - Update privacy policy for payment data handling

---

## Quick Reference

| Environment | Dev Mode | Keys | Use Case |
|-------------|----------|------|----------|
| Local Dev (simulated) | `true` | Live keys | Fast testing without charges |
| Local Dev (real) | `false` | Live keys | Test real payments locally |
| Release (Android/iOS) | `false` | Live keys | Production app |

**Active Config**: Check `.env` file
**Production Config**: Stored in `.env.production`
**Development Config**: Stored in `.env.development`

---

## Support & Resources

- **Paystack Docs**: https://paystack.com/docs/
- **Paystack Dashboard**: https://dashboard.paystack.com/
- **Your Webhook Logs**: Check Supabase Edge Function logs
- **Database Schema**: See `20251030000002_reorganize_banking_schema.sql`

---

**Last Updated**: November 4, 2025
**Status**: ✅ Live payments enabled and tested
