# URGENT: Fix Member Signup Now

## Quick Fix Steps (5 minutes)

### 1. Open Supabase Dashboard
- Go to: https://supabase.com/dashboard/project/qdrotavcmmevhgveodcp
- Navigate to: SQL Editor

### 2. Execute the Fix
- Click "New Query"
- Copy the entire content from `fix_trigger_now.sql` file
- Paste into the SQL Editor
- Click "Run" or press `Ctrl+Enter`

### 3. Verify Success
You should see: `Success. No rows returned`

### 4. Test Signup
- Open the Local Lekker app
- Try signing up with a test account
- Should now work without "Database error saving new user"

## What This Fixes
The database trigger was trying to set role='user' for members, but the database only allows:
- role='member'
- role='trusted_partner'  
- role='admin'

The fix changes the trigger to use role='member' for member signups.

## Alternative: Quick Temporary Fix
If you can't access the dashboard right now, you can disable the trigger temporarily:

1. Go to Supabase SQL Editor
2. Run this single line:
   ```sql
   DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
   ```
3. This will let the app handle profile creation (already implemented in the code)
4. Signups will work immediately
5. You can restore the trigger later with the proper fix

## Files to Reference
- `fix_trigger_now.sql` - The complete fix (copy this content to SQL Editor)
- `SIGNUP_ERROR_FIX.md` - Detailed explanation of the problem and solution
