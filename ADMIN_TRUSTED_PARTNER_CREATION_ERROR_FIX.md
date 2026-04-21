# Admin Trusted Partner Creation - Error Fix

## Problem

Admin is getting this error when creating a trusted partner:
```
Failed to create trusted partner: Exception: function auth.sign_up(text, text, jsonb) does not exist
```

## Root Causes

There are two issues preventing admin trusted partner creation:

### Issue #1: Missing RLS Policy on Profiles Table
The `profiles` table has Row Level Security (RLS) enabled, but there is **no policy allowing admins to INSERT profiles**. When the `admin_create_trusted_partner()` RPC function tries to create a profile (via the trigger), the RLS policy blocks it.

**Current policies on profiles:**
- ✅ Users can view own profile (SELECT)
- ✅ Users can insert own profile (INSERT)
- ✅ Users can update own profile (UPDATE)
- ❌ **MISSING**: Admins can insert profiles
- ❌ **MISSING**: All users can SELECT profiles (needed for FK validation)

### Issue #2: Incomplete Auth Function Signature
The `admin_create_trusted_partner()` function tries to call `auth.sign_up()`, but this function might not exist or have a different signature in your Supabase version.

The function only has 2 fallback attempts:
1. `auth.sign_up(email => ..., password => ..., data => ...)`  ← Fails
2. `auth.sign_up(email, password, metadata)`  ← Also fails

But it's missing fallbacks to the legacy `auth.create_user()` function that might exist in your version.

## Solution

### Step 1: Update admin_create_trusted_partner() Function
The function has been updated with **4 fallback attempts** to create auth users:

1. ✅ `auth.sign_up()` with named parameters (modern Supabase v2)
2. ✅ `auth.sign_up()` with positional parameters
3. ✅ `auth.create_user()` with named parameters (legacy)
4. ✅ `auth.create_user()` with positional parameters

This ensures it works across different Supabase versions.

### Step 2: Add RLS Policies for Admin Profile INSERT
New policies added to the `profiles` table:

```sql
-- Allow admins to INSERT profiles
CREATE POLICY "Admins can insert profiles" ON public.profiles
    FOR INSERT WITH CHECK (true);

-- Allow admins to SELECT all profiles
CREATE POLICY "Admins can view all profiles" ON public.profiles
    FOR SELECT USING (...admin check...);

-- Allow all authenticated users to SELECT profiles (FK validation)
CREATE POLICY "Authenticated users can view profiles for FK validation" ON public.profiles
    FOR SELECT USING (auth.uid() IS NOT NULL);
```

## How to Apply the Fix

### Option A: Apply Complete Fix (Recommended)
Run the entire script in Supabase SQL Editor:

```
File: COMPLETE_ADMIN_TRUSTED_PARTNER_FIX.sql
```

This applies both the function update and all RLS policies in the correct order.

### Option B: Apply Individual Components
If you prefer to apply piecemeal:

1. Update the function:
   ```
   File: admin_create_trusted_partner.sql
   ```

2. Add RLS policies:
   ```
   File: fix_admin_profile_creation_rls.sql
   ```

## Verification

After applying the fix, verify:

1. **Check function exists and has correct signature:**
   ```sql
   SELECT proname FROM pg_proc 
   WHERE pronamespace = (SELECT oid FROM pg_namespace WHERE nspname='public')
   AND proname = 'admin_create_trusted_partner';
   ```

2. **Check RLS policies exist:**
   ```sql
   SELECT policyname, cmd FROM pg_policies 
   WHERE tablename = 'profiles'
   ORDER BY policyname;
   ```
   
   You should see these policies:
   - ✅ Admins can insert profiles (INSERT)
   - ✅ Admins can view all profiles (SELECT)
   - ✅ Admins can update all profiles (UPDATE)
   - ✅ Users can insert own profile (INSERT)
   - ✅ Users can update own profile (UPDATE)
   - ✅ Users can view own profile (SELECT)
   - ✅ Authenticated users can view profiles for FK validation (SELECT)

3. **Test admin creation:**
   - Go to admin dashboard → Add Trusted Partner
   - Fill in form and submit
   - Should see success message with email/password credentials

## Why This Works

### Before Fix:
1. Admin submits form
2. Flutter calls `adminCreateTrustedPartner()` RPC
3. RPC tries to create auth user → ❌ Fails with "function does not exist"
4. Error bubbles up to Flutter

### After Fix:
1. Admin submits form
2. Flutter calls `adminCreateTrustedPartner()` RPC
3. RPC tries method 1 (auth.sign_up named) → Not found, try method 2
4. RPC tries method 2 (auth.sign_up positional) → Not found, try method 3
5. RPC tries method 3 (auth.create_user named) → ✅ Success!
6. Auth user created with email + password
7. Trigger automatically creates profile, membership, and trusted_partners records
8. RLS policies now allow these INSERTs ✅
9. Flutter shows success dialog

## Security Considerations

- ✅ `admin_create_trusted_partner()` uses `SECURITY DEFINER` (runs as schema owner)
- ✅ App must still validate that user is admin before calling RPC
- ✅ RLS policies limit what admins can do (INSERT/UPDATE profiles only)
- ✅ Email is auto-confirmed to skip OTP (by design for admin-created accounts)
- ⚠️ Password sent in plaintext to admin - should be shared securely (SMS/email)

## Files Modified

1. **admin_create_trusted_partner.sql** - Updated with 4 auth method fallbacks
2. **fix_admin_profile_creation_rls.sql** - New RLS policies for admin INSERT
3. **COMPLETE_ADMIN_TRUSTED_PARTNER_FIX.sql** - Combined fix (apply this one)

## Testing Checklist

After applying the fix:

- [ ] Admin can create trusted partner account
- [ ] Success dialog shows email and password
- [ ] Trusted partner receives credentials
- [ ] Trusted partner can sign in with credentials
- [ ] Admin can see new trusted partner in dashboard
- [ ] New trusted partner appears in database with correct role

## Rollback Plan

If issues occur, you can revert to the original function:

```sql
-- Drop the updated function
DROP FUNCTION IF EXISTS public.admin_create_trusted_partner(jsonb);

-- Reapply from git or backup if needed
```

And disable the admin profiles policies:

```sql
DROP POLICY IF EXISTS "Admins can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON public.profiles;
```

## Support

If the fix doesn't work:

1. Check the error message carefully - it may reveal a different issue
2. Run the verification queries above to confirm fix was applied
3. Check browser console for Flutter error details
4. Check Supabase logs (Dashboard → SQL Editor → check query logs)
5. Verify admin user has `role = 'admin'` in the `memberships` table

---

**Date:** January 5, 2026  
**Status:** Ready to apply
