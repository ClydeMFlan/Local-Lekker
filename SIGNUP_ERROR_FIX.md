# Member Signup Error Fix

## Problem
Members cannot sign up due to a database error: `AuthRetryableFetchException(message: {'code': "unexpected_failure","message":"Database error saving new user"}, statusCode: 500)`

## Root Cause
The database trigger `handle_new_user_role_assignment` was setting the role to 'user' for members, but the `profiles` table has a CHECK constraint that only allows:
- 'member'
- 'trusted_partner'  
- 'admin'

The trigger code had:
```sql
IF user_type = 'merchant' THEN
    user_role := 'merchant';
  ELSIF user_type = 'trusted_partner' THEN
    user_role := 'trusted_partner';
  ELSE
    user_role := 'user';  -- ❌ THIS VIOLATES THE CHECK CONSTRAINT!
  END IF;
```

## Solution

### Option 1: Update the Database Trigger (RECOMMENDED)
Execute the SQL in `fix_trigger_now.sql` or `supabase/migrations/20260105000000_fix_member_signup_trigger.sql` using the Supabase SQL Editor:

1. Go to Supabase Dashboard → SQL Editor
2. Create a new query
3. Paste the contents of `fix_trigger_now.sql`
4. Run the query

The fix changes the role mapping to:
```sql
IF user_type = 'merchant' THEN
    user_role := 'trusted_partner';
  ELSIF user_type = 'trusted_partner' THEN
    user_role := 'trusted_partner';
  ELSIF user_type = 'member' THEN
    user_role := 'member';
  ELSE
    user_role := 'member';  -- ✅ DEFAULT TO 'member'
  END IF;
```

### Option 2: Disable the Trigger Temporarily
If you need a quick workaround while fixing the trigger:

```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
```

Then the client-side `createUserProfile` function in `SupabaseService` will handle profile creation after OTP verification.

## Files Modified
- `supabase/migrations/20260105000000_fix_member_signup_trigger.sql` - New migration with fix
- `fix_trigger_now.sql` - Standalone SQL script to apply the fix immediately

## Testing
After applying the fix:
1. Try signing up a new member with the test data from the screenshot:
   - Email: henno163@gmail.com  
   - Name: (from form)
   - Address: 11 Drummond Street, Morelig, Bethlehem, Free State
   - Contact: 0765185163
2. Verify the signup completes without database errors
3. Verify the profile is created with role='member' in Supabase

## Related Files
- `lib/features/auth/members_signup_page.dart` - Member signup form
- `lib/services/supabase_service.dart` - Profile creation logic
- `supabase/migrations/20251125100511_update_trigger_for_trusted_partner.sql` - Original problematic trigger
