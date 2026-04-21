# Trusted Partner Member Registration Implementation

## Overview
Implemented trusted partner member registration flow in the member profile page, allowing trusted partners to register members using their unique key and collect personal banking details for in-app purchases.

## Database Schema
Personal banking details are stored in the `profiles` table:
- `bank_account_holder` - Account holder name
- `bank_name` - Bank name
- `bank_account_number` - Account number
- `bank_branch_code` - Branch code (6 digits)
- `bank_account_type` - Account type (Savings/Cheque/Transmission)
- `is_tp_member` - Boolean flag to identify TP members

Business banking details are stored in `trusted_partner_bank_accounts` table (for receiving payments from customers).

## Implementation Details

### 1. Member Profile Page Updates (`lib/features/auth/member_profile_page.dart`)

#### Added Controllers and State Variables:
- `_tpKeyController` - For trusted partner key input
- `_bankAccountHolderController` - For account holder name
- `_bankNameController` - For bank name
- `_bankAccountNumberController` - For account number
- `_bankBranchCodeController` - For branch code
- `_selectedBankAccountType` - For account type dropdown
- `_isTpMember` - Flag to track if user is already a TP member
- `_showBankingFields` - Controls visibility of banking fields
- `_isVerifyingKey` - Loading state during key verification

#### Key Verification Method:
```dart
Future<void> _verifyTrustedPartnerKey()
```
- Validates key format (12 characters)
- Queries `trusted_partners` table to verify key exists
- Shows banking fields on successful verification
- Displays appropriate error/success messages

#### Profile Save Logic:
- Saves banking details when `_showBankingFields` is true
- Sets `is_tp_member` flag to true
- Activates membership by updating `memberships` table:
  - Sets `status` to 'active'
  - Sets `gateway` to 'trusted_partner_key'
- No subscription required for TP members

### 2. UI Flow

#### Step 1: Toggle to Member View
- Trusted partner toggles to member view in their home page
- Opens `MembersHomePage`

#### Step 2: Access Profile Edit
- Navigate to member profile page
- See "Trusted Partner Member" section (if not already a TP member)

#### Step 3: Enter Key
- Paste 12-character unique key from trusted partner
- Click "Verify" button
- System validates key against database

#### Step 4: Complete Banking Details
- On successful verification, banking fields appear:
  - Account Holder Name
  - Bank Name
  - Account Type (dropdown)
  - Account Number
  - Branch Code (6 digits)

#### Step 5: Save Profile
- Click "Save" button
- System saves all profile data including banking details
- Marks user as TP member (`is_tp_member = true`)
- Activates membership (no payment required)
- Activates QR code for scanning

### 3. Key Features

#### Conditional Field Display:
- Banking fields only show after successful key verification
- If user is already a TP member, shows banking fields immediately
- Key field is disabled after verification

#### Validation:
- Key must be exactly 12 characters
- All banking fields are required
- Branch code must be exactly 6 digits
- Account type must be selected from dropdown

#### Membership Activation:
- Automatic activation on profile save
- No subscription payment required
- QR code becomes active immediately
- Gateway set to 'trusted_partner_key' for tracking

## Benefits

1. **For Trusted Partners:**
   - Can register members using unique key
   - Collect personal banking details for in-app purchases
   - No subscription fees for their members

2. **For Members:**
   - Free membership activation
   - Immediate QR code access
   - Secure banking details storage for in-app payments

3. **For System:**
   - Clear separation between business and personal banking
   - Trackable registration source (gateway = 'trusted_partner_key')
   - Secure key validation process

## Security Considerations

- Keys are validated against database before accepting
- Banking details are stored securely in profiles table
- Only verified keys can activate membership
- All fields are validated before saving
