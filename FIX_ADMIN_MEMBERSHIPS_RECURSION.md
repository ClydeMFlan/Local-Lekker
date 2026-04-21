# Fix: Infinite Recursion in Memberships Policies

## Problem
When an admin tries to create a trusted partner through the admin profile, the following error occurs:
```
PostgrestException(message: infinite recursion detected in policy for relation "memberships", code: 42P17)
```

## Root Cause
The issue is in the RLS (Row Level Security) policies on the `memberships` table. Specifically, the admin policies were checking the `memberships` table itself to verify if the current user is an admin:

```sql
CREATE POLICY "Admins can insert any membership" ON public.memberships
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.memberships  -- ❌ RECURSION HERE
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );
```

### Why This Causes Recursion:
1. Admin calls `complete_business_profile()` function
2. Function tries to INSERT into `memberships` table for new trusted partner
3. INSERT policy checks if current user is admin by querying `memberships` table
4. That SELECT query triggers SELECT policies on `memberships`
5. SELECT policies also check `memberships` table
6. **Infinite recursion detected** ❌

## Solution
Use the `profiles` table instead of querying `memberships` within the policy:

```sql
CREATE POLICY "Admins can insert any membership" ON public.memberships
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles  -- ✅ NO RECURSION
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
```

## Files Created
1. **`fix_admin_memberships_recursion.sql`** - Standalone script to run immediately
2. **`supabase/migrations/20251201000000_fix_admin_memberships_infinite_recursion.sql`** - Migration file

## How to Apply the Fix

### Option 1: Run the standalone script (Immediate fix)
```bash
psql $DATABASE_URL -f fix_admin_memberships_recursion.sql
```

### Option 2: Apply via Supabase migration
```bash
supabase db push
```

## Verification
After applying the fix, verify the policies are correct:

```sql
SELECT tablename, policyname, cmd, qual
FROM pg_policies
WHERE tablename = 'memberships' AND policyname LIKE '%Admin%'
ORDER BY policyname;
```

All admin policies should reference `profiles` table, NOT `memberships` table.

## Related Files
- `fix_admin_view_trusted_partners.sql` - Original file with the problematic policies
- `fix_complete_business_profile_logo.sql` - Function that triggers the INSERT
- `admin_delete_functions.sql` - Contains `is_admin()` helper function

## Testing
After applying the fix, test by:
1. Login as admin
2. Create a new trusted partner through admin interface
3. Should complete successfully without recursion error
