# Paystack Subaccounts Implementation Guide

## Overview
This implementation enables **automatic split payments** where trusted partners receive their share of deal payments directly from Paystack. When a member pays for a deal, the payment is automatically split between the partner (90%) and the platform (10%).

## Architecture

### Components Added

#### 1. PaystackService Methods
**Location**: `lib/services/paystack_service.dart`

New methods:
- `createSubaccount()` - Creates a Paystack subaccount for a trusted partner
- `updateSubaccount()` - Updates subaccount details
- `getSubaccount()` - Retrieves subaccount information
- `startOneTimePayment()` - Enhanced to accept optional `subaccountCode` parameter

#### 2. Database Schema
**Migration File**: `add_paystack_subaccounts.sql`

Added columns to `trusted_partner_bank_accounts`:
- `subaccount_code` (TEXT) - Paystack subaccount ID (e.g., ACCT_xxxxx)
- `percentage_charge` (NUMERIC) - Partner's percentage (default 90.0)
- `subaccount_created_at` (TIMESTAMP) - When subaccount was created
- `subaccount_active` (BOOLEAN) - Whether split payments are enabled

#### 3. Business Profile Page
**Location**: `lib/features/auth/business_profile_page.dart`

Enhanced `_saveBankingDetails()` to:
1. Create transfer recipient (for future manual transfers)
2. Create Paystack subaccount (for automatic split payments)
3. Store both codes in database

#### 4. Deal Payment Flow
**Location**: `lib/services/deal_approval_popup_service.dart`

Enhanced `_processPaystackPayment()` to:
1. Fetch partner's subaccount code from database
2. Pass subaccount code to payment initialization
3. Payment automatically splits between partner and platform

## How It Works

### Setup Flow (Trusted Partner)
1. Partner navigates to Business Profile → Banking Details
2. Enters bank account information (name, number, bank, branch code)
3. System calls:
   - `createTransferRecipient()` → Gets recipient code for transfers
   - `createSubaccount()` → Gets subaccount code for split payments
4. Both codes stored in `trusted_partner_bank_accounts` table
5. `subaccount_active` set to `true`

### Payment Flow (Member)
1. Member selects deal and requests authorization
2. Partner approves deal
3. Member clicks "Pay" button
4. System:
   - Fetches partner's business ID
   - Looks up `subaccount_code` from `trusted_partner_bank_accounts`
   - Checks if `subaccount_active = true`
5. Payment initialization includes subaccount:
   ```dart
   await paystackService.startOneTimePayment(
     itemName: 'Steak at Momsie',
     itemDescription: 'Payment to Momsie for Steak',
     amount: 10.50,
     userId: memberId,
     userEmail: memberEmail,
     subaccountCode: 'ACCT_xxxxx', // Partner's subaccount
   );
   ```
6. Paystack automatically splits payment:
   - Partner receives 90% directly to their bank account
   - Platform receives 10% in Local Lekker account

### Split Payment Details
- **Default Split**: Partner 90%, Platform 10%
- **Settlement**: Partner receives funds within Paystack's settlement period
- **Payment Page**: Shows partner's business name instead of "Local Lekker Club"
- **Transaction Fee**: Charged to platform account (Local Lekker)

## Database Schema

### trusted_partner_bank_accounts Table
```sql
CREATE TABLE trusted_partner_bank_accounts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID REFERENCES businesses(id),
  user_id UUID REFERENCES auth.users(id),
  account_holder_name TEXT NOT NULL,
  bank_name TEXT NOT NULL,
  account_type TEXT NOT NULL,
  account_number TEXT NOT NULL, -- Masked (last 4 digits only)
  branch_code TEXT,
  paystack_recipient_code TEXT, -- For manual transfers
  subaccount_code TEXT,          -- For split payments
  percentage_charge NUMERIC(5,2) DEFAULT 90.0,
  subaccount_created_at TIMESTAMP WITH TIME ZONE,
  subaccount_active BOOLEAN DEFAULT true,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## API Reference

### createSubaccount()
Creates a Paystack subaccount for split payments.

```dart
Future<String?> createSubaccount({
  required String businessName,
  required String bankCode,
  required String accountNumber,
  required String businessId,
  double percentageCharge = 90.0,
}) async
```

**Parameters:**
- `businessName` - Name of the business (shown on payment page)
- `bankCode` - Paystack bank code (e.g., "632005" for FNB)
- `accountNumber` - Full bank account number
- `businessId` - Business UUID for metadata
- `percentageCharge` - Percentage partner receives (default 90.0)

**Returns:** Subaccount code (e.g., "ACCT_xxxxx") or `null` on failure

**Paystack Endpoint:** `POST /subaccount`

### updateSubaccount()
Updates an existing subaccount.

```dart
Future<bool> updateSubaccount({
  required String subaccountCode,
  String? businessName,
  String? bankCode,
  String? accountNumber,
  double? percentageCharge,
}) async
```

### getSubaccount()
Retrieves subaccount details from Paystack.

```dart
Future<Map<String, dynamic>?> getSubaccount(String subaccountCode) async
```

## Benefits vs. Transfer Recipients

| Feature | Subaccounts (Option B) | Transfer Recipients (Option A) |
|---------|------------------------|-------------------------------|
| **Split Timing** | Automatic at charge time | Manual after payment |
| **Payment Page Display** | Shows partner name | Shows "Local Lekker Club" |
| **Implementation Complexity** | More complex setup | Simpler |
| **Partner Onboarding** | Requires bank verification | Minimal requirements |
| **Fund Flow** | Direct to partner | Platform → Partner |
| **Transaction Transparency** | High (shown on statement) | Lower (shows platform) |
| **Platform Control** | Less (auto-split) | More (manual transfer) |
| **Settlement Speed** | Paystack's schedule | Platform-controlled |

## Requirements

### Paystack Account
- **Tier**: Subaccounts may require business/verified tier
- **KYC**: Partner bank accounts must be verified
- **Bank Codes**: Must use correct Paystack bank codes (not branch codes)

### South African Banks (Common Codes)
- Absa Bank: `632005`
- Capitec Bank: `470010`
- FNB: `250655`
- Nedbank: `198765`
- Standard Bank: `051001`
- Investec: `580105`
- African Bank: `430000`

## Testing

### Development Mode
When `PAYSTACK_DEVELOPMENT_MODE=true`:
- Subaccount creation returns simulated code
- Split payments not actually processed
- Use for testing UI flow

### Production Mode
When `PAYSTACK_DEVELOPMENT_MODE=false`:
1. Ensure partner enters correct bank details
2. Verify bank code matches Paystack's codes
3. Test with small amount first (e.g., R10)
4. Check partner's bank statement for settlement

## Error Handling

### Subaccount Creation Failure
If subaccount creation fails:
- System logs warning but continues
- Partner can still receive transfers via recipient code
- `subaccount_active` set to `false`
- Payment goes to platform account (no split)

### Payment with Missing Subaccount
If no active subaccount found:
- Payment proceeds without subaccount parameter
- Funds go to platform account (Local Lekker)
- Manual transfer required using recipient code

## Monitoring

### Check Subaccount Status
```sql
SELECT 
  businesses.name AS business_name,
  tp.account_holder_name,
  tp.bank_name,
  tp.subaccount_code,
  tp.percentage_charge,
  tp.subaccount_active,
  tp.subaccount_created_at
FROM trusted_partner_bank_accounts tp
JOIN businesses ON businesses.id = tp.business_id
WHERE tp.subaccount_active = true
ORDER BY tp.created_at DESC;
```

### Verify Split Payments
Check Paystack Dashboard:
1. Transactions → Filter by subaccount
2. Settlements → View partner settlements
3. Subaccounts → Manage subaccounts

## Migration Steps

### Step 1: Run Database Migration
```bash
# Apply schema changes
psql -h your-supabase-url -d postgres -f add_paystack_subaccounts.sql
```

### Step 2: Deploy Code
```bash
flutter build apk --release
```

### Step 3: Partner Onboarding
1. Notify existing partners to update banking details
2. Partners re-enter banking information in Business Profile
3. System automatically creates subaccounts

### Step 4: Verification
1. Test payment flow with test partner
2. Verify split appears in Paystack dashboard
3. Confirm partner receives settlement

## Troubleshooting

### Error: "Subaccount creation failed"
**Causes:**
- Invalid bank code
- Account number doesn't match bank
- Paystack account not verified
- API key lacks subaccount permissions

**Solutions:**
1. Verify bank code from Paystack documentation
2. Confirm account number is correct
3. Check Paystack account verification status
4. Ensure live API keys have full permissions

### Error: "No active subaccount found"
**Causes:**
- Partner hasn't set up banking details
- Subaccount creation failed during setup
- `subaccount_active` set to false

**Solutions:**
1. Partner should update banking details in Business Profile
2. Check database for `subaccount_active` flag
3. Manually create subaccount via Paystack dashboard

### Split percentage not correct
**Causes:**
- `percentage_charge` value in database incorrect
- Subaccount updated with wrong percentage

**Solutions:**
1. Update database: `UPDATE trusted_partner_bank_accounts SET percentage_charge = 90.0 WHERE business_id = ?`
2. Call `updateSubaccount()` with correct percentage

## Future Enhancements

1. **Dynamic Split Percentage**: Allow different percentages per deal
2. **Admin Dashboard**: View all subaccounts and split history
3. **Partner Analytics**: Show partners their settlement history
4. **Automated Onboarding**: Email partners to complete setup
5. **Subaccount Verification**: Add UI to test subaccount before activation

## References

- [Paystack Subaccounts Documentation](https://paystack.com/docs/payments/subaccounts)
- [Paystack Bank Codes](https://paystack.com/docs/payments/bank-codes)
- Local Lekker Architecture: See `copilot-instructions.md`
