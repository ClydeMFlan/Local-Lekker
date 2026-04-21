# Password Reset Flow - Complete Solution

## Current Problem
- Email sends a "log in" magic link instead of password reset flow
- When user clicks the link, they're signed in and see home page
- Password reset page is never shown

## Root Cause
The Site URL configuration and email template flow are misaligned. We need:
1. **Site URL** = where Supabase redirects AFTER recovery email is verified
2. **Recovery Session** = tracked in database so app can show reset page on startup
3. **App Startup** = detects recovery session and shows PasswordResetPage

## Complete Fix

### Step 1: Set Site URL to trigger deep link
In Supabase Dashboard → Authentication → URL Configuration:
- **Site URL**: `locallekker://auth/callback`

This makes the recovery email link open the app directly.

### Step 2: Verify RLS Policy allows reading recovery_sessions

Run this to fix RLS:
```sql
-- Allow anyone to read active recovery sessions for password reset flow
DROP POLICY IF EXISTS "Users can read own recovery sessions" ON public.recovery_sessions;
DROP POLICY IF EXISTS "Anyone can read active recovery sessions" ON public.recovery_sessions;

CREATE POLICY "Anyone can read active recovery sessions"
  ON public.recovery_sessions
  FOR SELECT
  USING (used = false AND expires_at > NOW());

CREATE POLICY "Anyone can insert recovery session"
  ON public.recovery_sessions
  FOR INSERT
  WITH CHECK (true);
```

### Step 3: Test the complete flow

1. **App**: Click "Forgot password" for user email
   - App creates recovery_sessions entry ✓
   - App calls /recover endpoint to send email ✓
   
2. **Email**: Receive password recovery email
   - Email has a link (doesn't matter if it says "login" or "reset")
   - Click the link
   
3. **App**: Opens from deep link
   - NavigationService checks for active recovery_sessions
   - If found, shows PasswordResetPage instead of home page
   - User can set new password
   
4. **Database**: recovery_sessions is marked as used
   - Prevents reuse of same recovery token

## Files Modified
- `lib/services/supabase_service.dart` - Added `_sendPasswordRecoveryEmail()` with recovery_sessions creation
- `lib/services/navigation_service.dart` - Added recovery_sessions check at app startup
- Database: `recovery_sessions` table with RLS policies

## Expected Email Content
The email will still say "log in" or have a generic link, but when user clicks it:
1. Opens the app via deep link `locallekker://auth/callback`
2. App startup detects the recovery_sessions entry
3. Shows PasswordResetPage immediately
4. User can change password

The recovery is seamless even if the email wording is "log in".
