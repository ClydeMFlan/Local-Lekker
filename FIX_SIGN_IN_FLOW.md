# Fix: Member Sign-In Flow with Pending Payments

## Problem
Members who completed signup but signed out before making payment couldn't sign in. The app reported "email not found" even though the account existed.

## Root Causes
1. **Email Case Sensitivity**: Emails weren't being normalized (lowercase) consistently between signup and sign-in
2. **Subscription Status Logic**: The navigation service wasn't properly checking subscription status from the `subscriptions` table
3. **Profile Email Storage**: Email in profiles table might not match case with auth.users

## Changes Made

### 1. Email Normalization (`supabase_service.dart`)
- **signUp()**: Now normalizes email to `lowercase().trim()` before creating account
- **signIn()**: Now normalizes email to `lowercase().trim()` before authentication
- **createUserProfile()**: Stores email as `lowercase().trim()` in profiles table
- **checkEmailExists()**: Searches for email using `lowercase().trim()`

### 2. Improved Subscription Status Check (`navigation_service.dart`)
Updated `_getSubscriptionStatus()` to:
1. First check `subscriptions` table for active subscription
2. Fall back to `profiles.subscription` field if no active subscription found
3. Default to 'pending' if status cannot be determined

### 3. Navigation Logic Updates (`navigation_service.dart`)
Updated routing logic to properly handle members with pending payments:
- If subscription is 'active' → Navigate to `MembersHomePage`
- If subscription is 'pending' or doesn't exist → Navigate to `PaymentRequiredScreen`

## Expected Flow After Fix

### Scenario 1: New Member Signup (Complete Flow)
1. ✅ Member fills out signup form
2. ✅ Member enters OTP → Profile created with `subscription: 'pending'`
3. ✅ Member redirected to `PaymentOptionsScreen`
4. ✅ Member completes Paystack payment
5. ✅ Subscription created with `status: 'active'`
6. ✅ Member directed to `MembersHomePage`

### Scenario 2: Member Signs Out Before Payment (FIXED)
1. ✅ Member fills out signup form
2. ✅ Member enters OTP → Profile created with `subscription: 'pending'`
3. ✅ Member redirected to `PaymentOptionsScreen`
4. ❌ Member signs out (closes app)
5. ✅ Member reopens app → `WelcomePage` shown
6. ✅ Member clicks "Sign In"
7. ✅ **Email is found** (normalized lookup works)
8. ✅ Member enters password → Successfully authenticated
9. ✅ NavigationService checks subscription status → 'pending'
10. ✅ Member directed to `PaymentRequiredScreen`
11. ✅ Member completes payment through Paystack
12. ✅ Member directed to `MembersHomePage`

## Testing Steps

### Test 1: New User Complete Flow
```bash
# Clean start
flutter run

# Steps:
1. Click "Sign Up" → Choose "Member"
2. Fill all details with email: test@example.com
3. Enter OTP code from email
4. Should see PaymentOptionsScreen
5. Complete payment via Paystack
6. Should land on MembersHomePage with QR code
```

### Test 2: Sign Out Before Payment (Primary Fix)
```bash
# Start fresh
flutter run

# Steps:
1. Click "Sign Up" → Choose "Member"
2. Fill details with email: test2@example.com
3. Enter OTP code
4. See PaymentOptionsScreen → Click "Sign Out"
5. App returns to WelcomePage
6. Click "Sign In"
7. Enter email: test2@example.com (or TEST2@EXAMPLE.COM - case shouldn't matter)
8. Enter password
9. Should see PaymentRequiredScreen (NOT "email not found" error)
10. Complete payment
11. Should land on MembersHomePage
```

### Test 3: Email Case Insensitivity
```bash
# Steps:
1. Sign up with: MyEmail@Example.Com
2. Sign out
3. Sign in with: myemail@example.com (all lowercase)
4. Should work without "email not found" error
```

### Test 4: Existing User with Active Subscription
```bash
# Steps:
1. Sign in with existing paid member account
2. Should go directly to MembersHomePage
3. Should see QR code and subscription status
```

## Database Schema Requirements

Ensure these tables/columns exist:

### `profiles` table
```sql
- id (uuid, primary key)
- email (text, unique, indexed)
- subscription (text) -- 'pending' or 'active'
- name, surname, etc.
```

### `subscriptions` table
```sql
- id (uuid, primary key)
- user_id (uuid, foreign key to profiles)
- status (text) -- 'active', 'cancelled', etc.
- current_period_end (timestamptz)
```

## Rollback Plan
If issues occur, revert these files:
```bash
git checkout HEAD -- lib/services/supabase_service.dart
git checkout HEAD -- lib/services/navigation_service.dart
```

## Additional Notes

### Logging Added
All critical paths now log with emoji prefixes for easier debugging:
- 🔍 Email checking
- 🔐 Authentication
- 📊 Subscription status
- 🎬 Navigation

### Edge Cases Handled
1. Email with mixed case (Test@Example.Com)
2. Email with leading/trailing spaces
3. Missing subscription record (defaults to 'pending')
4. RLS policy restrictions (falls back to safe defaults)

## Related Files
- `lib/services/supabase_service.dart` - Auth & profile creation
- `lib/services/navigation_service.dart` - Screen routing logic
- `lib/features/auth/welcome_page.dart` - Sign-in dialog
- `lib/features/payments/payments_feature.dart` - Payment screens
- `lib/widgets/loading_screen.dart` - Auto-navigation after auth
