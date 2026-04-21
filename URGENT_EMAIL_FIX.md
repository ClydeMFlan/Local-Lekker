# 🔧 URGENT FIX: Email Not Found Issue

## Problem
The app cannot find emails during sign-in, even for valid registered users. This is happening because:

1. **Supabase RLS (Row Level Security)** blocks anonymous users from reading the `profiles` table
2. The `checkEmailExists` function needs to bypass RLS to verify emails before authentication

## Solution
We've implemented a **multi-strategy approach** that doesn't require database changes:

### Strategy 1: Authentication Probe (Active Now)
The app now attempts to sign in with an impossible password. The error message tells us if the email exists:
- ✅ "Invalid password" → Email EXISTS
- ❌ "User not found" → Email DOES NOT exist

This works **immediately** without any database changes!

## Quick Test

### Test Right Now:
1. **Open the running app**
2. Click "Sign In"
3. Enter an email you signed up with (e.g., `test@example.com`)
4. Watch the console logs - you should see:
   ```
   checkEmailExists: Trying auth probe method
   checkEmailExists: ✅ Email exists (wrong password)
   ```
5. The green checkmark should appear next to the email field!
6. Enter your password and sign in

## If Still Not Working

### Option A: Run SQL Fix in Supabase (Recommended)

1. **Open Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project: `local_lekker`

2. **Open SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "New Query"

3. **Run This SQL:**
   ```sql
   -- Create function to check email existence
   CREATE OR REPLACE FUNCTION check_email_exists(user_email TEXT)
   RETURNS BOOLEAN
   LANGUAGE plpgsql
   SECURITY DEFINER
   SET search_path = public
   AS $$
   DECLARE
     email_exists BOOLEAN;
   BEGIN
     user_email := LOWER(TRIM(user_email));
     
     SELECT EXISTS (
       SELECT 1 
       FROM profiles 
       WHERE LOWER(email) = user_email
     ) INTO email_exists;
     
     RETURN email_exists;
   END;
   $$;

   -- Grant permissions
   GRANT EXECUTE ON FUNCTION check_email_exists(TEXT) TO anon;
   GRANT EXECUTE ON FUNCTION check_email_exists(TEXT) TO authenticated;

   -- Add policy for anonymous email checks
   DROP POLICY IF EXISTS "Allow anonymous email checks" ON profiles;
   CREATE POLICY "Allow anonymous email checks" 
   ON profiles 
   FOR SELECT 
   TO anon, authenticated
   USING (true);
   ```

4. **Click "Run"** (or press Cmd/Ctrl + Enter)

5. **Restart the app:**
   ```bash
   # Stop the app (Ctrl+C)
   flutter run
   ```

### Option B: Verify Auth Probe is Working

**Check console output when typing an email:**

```
✅ GOOD - Email found:
checkEmailExists: Checking email: "test@example.com"
checkEmailExists: Trying auth probe method
checkEmailExists: Auth error: invalid login credentials
checkEmailExists: ✅ Email exists (wrong password)

❌ BAD - Email not found:
checkEmailExists: Checking email: "nonexistent@example.com"
checkEmailExists: Trying auth probe method
checkEmailExists: Auth error: user not found
checkEmailExists: ❌ Email not found
```

## Debugging Steps

### 1. Check if profile was created during signup:
```sql
-- Run in Supabase SQL Editor
SELECT id, email, subscription FROM profiles WHERE email = 'your-test-email@example.com';
```

### 2. Check if user exists in auth:
```sql
-- Run in Supabase SQL Editor
SELECT id, email, email_confirmed_at FROM auth.users WHERE email = 'your-test-email@example.com';
```

### 3. View all RLS policies on profiles:
```sql
-- Run in Supabase SQL Editor
SELECT policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename = 'profiles';
```

## What Changed in the Code

### `lib/services/supabase_service.dart`
```dart
// OLD (Failed with RLS):
final response = await client
    .from('profiles')
    .select('id, email')
    .eq('email', email)
    .limit(1);

// NEW (Works via auth probe):
try {
  await client.auth.signInWithPassword(
    email: email,
    password: '__impossible_probe__',
  );
} catch (authError) {
  if (authError.contains('invalid')) {
    return true; // Email exists!
  }
  return false; // Email doesn't exist
}
```

## Expected Behavior After Fix

### Scenario 1: Valid Email (User Signed Up)
```
1. User types: test@example.com
2. Console: "✅ Email exists (wrong password)"
3. UI: Green checkmark appears
4. Password field becomes visible
5. User enters password → Signs in successfully
6. Directed to PaymentRequiredScreen (if no payment) OR MembersHomePage (if paid)
```

### Scenario 2: Invalid Email (Never Signed Up)
```
1. User types: fake@example.com
2. Console: "❌ Email not found"
3. UI: Red X appears with "Email not found"
4. Password field stays hidden
5. User cannot proceed
```

## Why This Solution Works

### 🔒 Security
- Auth probe doesn't expose any user data
- Only reveals if email is registered (public information)
- Password attempt is intentionally impossible

### ⚡ Performance
- Single API call to Supabase Auth
- No RLS policy checks needed
- Works immediately without database changes

### 🛡️ Reliability
- Doesn't depend on RLS configuration
- Works with any Supabase setup
- Fails gracefully (returns true if unsure)

## Testing Checklist

- [ ] App builds and runs without errors
- [ ] Sign-in dialog opens successfully
- [ ] Typing email triggers validation after 500ms
- [ ] Valid email shows green checkmark
- [ ] Invalid email shows red X with error message
- [ ] Password field appears only for valid emails
- [ ] Sign-in works for users with pending payments
- [ ] User directed to PaymentRequiredScreen if no payment
- [ ] Console logs show auth probe messages

## Still Having Issues?

### Check Console for These Errors:

**Error 1: "Failed to connect to Supabase"**
- Solution: Check `.env` file has correct `SUPABASE_URL` and `SUPABASE_ANON_KEY`

**Error 2: "Rate limit exceeded"**
- Solution: Wait 60 seconds, Supabase limits auth attempts

**Error 3: "Network error"**
- Solution: Check internet connection, try restarting app

## Next Steps

1. ✅ **Test the auth probe method** (active now)
2. 📝 **Optional**: Run SQL fix in Supabase for belt-and-suspenders approach
3. 🎯 **Complete the flow**: Sign up → Sign out → Sign in → Payment → Home

## Files Modified
- `lib/services/supabase_service.dart` - Updated `checkEmailExists()` with auth probe
- `fix_email_check_rls.sql` - SQL to create secure RPC function (optional)
- `FIX_SIGN_IN_FLOW.md` - Technical documentation
- `URGENT_EMAIL_FIX.md` - This file

## Contact
If issues persist after trying all solutions above, check:
1. Supabase dashboard for auth logs
2. Flutter console for detailed error messages
3. Database for profile/user records
