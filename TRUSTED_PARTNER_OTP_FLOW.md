# Trusted Partner OTP Authentication Flow (No Temp Password)

## Overview
This document describes the updated authentication flow for trusted partners, where admin creates the account, sends OTP, and the trusted partner verifies via OTP then creates their own password.

## Flow Description

### 1. Admin Creates Trusted Partner Account
**File:** `lib/features/admin/admin_add_trusted_partner_page.dart`

- Admin fills in trusted partner details (name, email, business name, etc.)
- System calls `SupabaseService.instance.signUpWithOtp()` which uses `signInWithOtp` with `shouldCreateUser: true`
- **No temporary password is created**
- Supabase sends OTP to trusted partner's email
- User profile is created in `auth.users` with metadata:
  - `admin_created: true`
  - `email_verified: false`
  - `password_set: false`
  - `user_type: 'trusted_partner'`
- Profile is created in `profiles` table
- Trusted partner record is created in `trusted_partners` table
- Membership record is created in `memberships` table with role `'trusted_partner'`
- Admin sees success dialog with message that OTP was sent to trusted partner

### 2. Trusted Partner Receives OTP
- Trusted partner receives email with 6-digit OTP code
- OTP is valid for 2 minutes (120 seconds)

### 3. Trusted Partner Signs In
**File:** `lib/features/auth/welcome_page.dart`

- Trusted partner clicks "Sign In" button
- Enters their email address
- System checks email in profiles table:
  - If email exists and `admin_created: true` and `email_verified: false`
  - System automatically shows OTP verification dialog
  - Trusted partner enters the OTP received via email

### 4. OTP Verification
**File:** `lib/features/auth/widgets/otp_verification_dialog.dart`

- Dialog shows email address
- 6-digit OTP input field
- 2-minute countdown timer
- Resend OTP option (after timer expires or on demand)
- Verify button calls `SupabaseService.instance.verifyOtp()`
- On success, calls `onVerificationSuccess` callback with userId

### 5. Create Password
**File:** `lib/features/auth/set_password_page.dart`

- After successful OTP verification, system checks `password_set` status
- If `password_set: false`, redirects to SetPasswordPage
- Trusted partner creates their own secure password with requirements:
  - At least 8 characters
  - One uppercase letter (A-Z)
  - One lowercase letter (a-z)
  - One number (0-9)
  - One special character (!@#$%^&*)
- Password is saved via `SupabaseService.instance.updatePassword()`
- Profile is updated: `password_set: true`, `email_verified: true`
- User is redirected to trusted partner home page

## Database Schema Requirements

### profiles table
Must have the following columns:
- `email` (text, unique)
- `admin_created` (boolean, default: false)
- `email_verified` (boolean, default: true)
- `password_set` (boolean, default: true)

### trusted_partners table
- `id` (uuid, primary key)
- `user_id` (uuid, foreign key to auth.users)
- `business_name` (text, not null)
- `created_at` (timestamptz, default: now())

### memberships table
- `user_id` (uuid, foreign key to auth.users)
- `role` (text, e.g., 'trusted_partner', 'admin', 'member')
- `gateway` (text, e.g., 'admin_created', 'self_signup')

## Code Changes

### 1. `lib/services/supabase_service.dart`
Existing function used:
```dart
Future<AuthResponse> signUpWithOtp({
  required String email,
  Map<String, dynamic>? userMetadata,
})
```
- Uses `client.auth.signInWithOtp()` with `shouldCreateUser: true`
- Sends OTP to email
- Returns AuthResponse

Updated function:
```dart
Future<Map<String, dynamic>> checkAdminCreatedStatus(String email)
```
- Now also checks `email_verified` and `password_set` status
- Returns map with `admin_created`, `password_set`, and `email_verified`

### 2. `lib/features/admin/admin_add_trusted_partner_page.dart`
Modified `_createTrustedPartner()` function:
- Uses `signUpWithOtp()` to create user without password
- Sets metadata: `password_set: false`, `email_verified: false`
- Immediately sends OTP for email verification
- Updated success dialog to inform admin that OTP was sent

### 3. `lib/features/auth/welcome_page.dart`
Modified `_showSigninDialog()` function:
- Added check for unverified trusted partners in email validation
- If `admin_created: true` and `email_verified: false`, shows OTP verification dialog

Modified `_showOtpVerificationForTrustedPartner()` function:
- After successful OTP verification, checks `password_set` status
- If `password_set: false`, redirects to SetPasswordPage
- If `password_set: true`, proceeds to home page

### 4. `lib/features/auth/set_password_page.dart` (NEW)
New page for trusted partners to create their password:
- Password input with validation
- Confirm password input
- Password requirements display
- Updates password via `updatePassword()`
- Updates profile: `password_set: true`, `email_verified: true`
- Redirects to appropriate home page based on user role

## Benefits of This Approach

1. **Security**: No temporary passwords to manage or share
2. **User Control**: Trusted partner creates their own password
3. **User Experience**: Seamless flow from OTP verification to password creation
4. **Simplicity**: Single OTP verification, then password creation
5. **Consistency**: Uses same OTP mechanism as other authentication flows
6. **Email Verification**: Ensures trusted partner has access to the email address

## Database Migration

Run the following SQL to set up the database:

```sql
-- Add email_verified column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT true;

-- Add password_set column to profiles table
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS password_set BOOLEAN DEFAULT true;

-- Update existing admin-created users to have correct status
UPDATE profiles 
SET email_verified = false,
    password_set = false
WHERE admin_created = true 
  AND id IN (
    SELECT au.id 
    FROM auth.users au 
    WHERE au.raw_user_meta_data->>'admin_created' = 'true' 
      AND au.raw_user_meta_data->>'email_verified' = 'false'
      AND au.email_confirmed_at IS NULL
  );

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_profiles_email_verified 
ON profiles(email, email_verified);

CREATE INDEX IF NOT EXISTS idx_profiles_password_set 
ON profiles(password_set);
```

## Testing Checklist

- [ ] Admin can create trusted partner account
- [ ] OTP is sent to trusted partner email (no temp password created)
- [ ] Trusted partner receives OTP email
- [ ] Trusted partner can enter email on sign-in page
- [ ] System recognizes unverified trusted partner
- [ ] OTP verification dialog appears automatically
- [ ] Trusted partner can enter OTP
- [ ] OTP verification succeeds
- [ ] Set Password page appears after OTP verification
- [ ] Password validation works correctly
- [ ] Password requirements are displayed
- [ ] Confirm password validation works
- [ ] Password is saved successfully
- [ ] Profile is marked as verified and password_set in database
- [ ] Trusted partner is redirected to home page
- [ ] Resend OTP works correctly
- [ ] Timer countdown works correctly
- [ ] Error handling works for invalid OTP
- [ ] Error handling works for expired OTP
- [ ] Error handling works for weak passwords

## Troubleshooting

### OTP Not Received
- Check spam/junk folder
- Verify email address is correct
- Check Supabase email settings
- Use "Resend OTP" option

### OTP Verification Fails
- Ensure OTP is entered correctly (6 digits)
- Check if OTP has expired (2 minutes)
- Request new OTP if expired

### Email Not Recognized
- Verify admin created the account
- Check profiles table for email
- Ensure email is lowercase and trimmed

### Password Creation Fails
- Ensure password meets all requirements
- Check that user is authenticated after OTP verification
- Verify Supabase session is active

### User Can't Access Home Page
- Verify `password_set: true` in profiles table
- Verify `email_verified: true` in profiles table
- Check user role in memberships table
