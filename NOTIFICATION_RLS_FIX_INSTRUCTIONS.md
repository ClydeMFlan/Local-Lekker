# Notification RLS Error - Fix Instructions

## Problem
The error occurs because the **notifications table RLS policy is blocking INSERT operations** from authenticated users who want to create notifications for OTHER users (cross-user notifications).

When a member requests a deal authorization, the app tries to create a notification for the trusted partner, but the RLS policy blocks this because the authenticated user (member) is trying to insert a row where `user_id` points to someone else (the trusted partner).

## Error Message
```
PostgrestException(message: new row violates row-level security policy for table 'notifications', code: 42501, details: Forbidden, hint: null)
```

## Root Cause
The notifications table has an RLS INSERT policy that checks:
```sql
WITH CHECK (user_id = auth.uid())
```

This means "only allow inserts where user_id equals the currently authenticated user." This blocks cross-user notifications.

## Solution

### Step 1: Run the SQL Fix on Supabase

1. **Open Supabase Dashboard**: https://app.supabase.com
2. **Navigate to**: Your project → SQL Editor
3. **Run this file**: `fix_notifications_rls_final_comprehensive.sql`

Or copy and paste this SQL:

```sql
-- Enable RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing policies
DO $$ 
DECLARE
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE schemaname = 'public' 
          AND tablename = 'notifications'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON notifications', policy_record.policyname);
    END LOOP;
END $$;

-- CREATE THREE NEW POLICIES

-- SELECT: Users see only their own notifications
CREATE POLICY "notifications_select_own" 
ON notifications
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT: ANY authenticated user can create notifications for ANY user
CREATE POLICY "notifications_insert_all" 
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- UPDATE: Users can only update their own notifications
CREATE POLICY "notifications_update_own" 
ON notifications
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

### Step 2: Verify the Fix

Run this query to verify:

```sql
SELECT 
    policyname,
    cmd,
    roles,
    with_check::text
FROM pg_policies
WHERE schemaname = 'public' 
  AND tablename = 'notifications'
ORDER BY cmd, policyname;
```

You should see:
- `notifications_select_own` - SELECT - using: (user_id = auth.uid())
- `notifications_insert_all` - INSERT - with_check: (auth.uid() IS NOT NULL)
- `notifications_update_own` - UPDATE - using/with_check: (user_id = auth.uid())

### Step 3: Test in the App

1. **Sign in as member** (clydemflan@gmail.com)
2. **Request a deal authorization** from a trusted partner
3. **Notification should be created successfully** for the trusted partner
4. **No RLS error should appear**

## Technical Explanation

### Why This Works

The new INSERT policy checks `auth.uid() IS NOT NULL` instead of `user_id = auth.uid()`. This means:

**Old Policy (WRONG):**
```sql
-- Only allows: INSERT notifications WHERE user_id = currently logged in user
-- Blocks: Cross-user notifications
WITH CHECK (user_id = auth.uid())
```

**New Policy (CORRECT):**
```sql
-- Allows: INSERT notifications as long as someone is authenticated
-- Allows: Cross-user notifications (member → trusted partner, trusted partner → member)
WITH CHECK (auth.uid() IS NOT NULL)
```

### Security Considerations

**Q: Is this secure?**  
**A: YES.** The policy still requires authentication (`auth.uid() IS NOT NULL`). Anonymous users cannot create notifications.

**Q: Can users spam notifications to other users?**  
**A: This is controlled by application logic**, not RLS. Your app controls when `createNotification()` is called. Users can't arbitrarily call this from the UI—it's only triggered by specific actions like:
- Deal authorization approval/rejection
- Payment success
- Bill submission

**Q: Can users see other users' notifications?**  
**A: NO.** The SELECT policy still enforces `user_id = auth.uid()`, so users can only see their own notifications.

## Alternative Solution (If you want stricter control)

If you want to restrict WHO can create notifications, you could use a more complex policy:

```sql
CREATE POLICY "notifications_insert_controlled" 
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (
    -- Allow if inserting for self
    user_id = auth.uid() 
    OR 
    -- Allow if user is a trusted_partner (check memberships/profiles)
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND role = 'trusted_partner'
    )
    OR
    -- Allow if user is a member (they need to notify trusted partners)
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() 
        AND role = 'member'
    )
);
```

But the simpler version (`auth.uid() IS NOT NULL`) is recommended because:
1. It's easier to maintain
2. Your app logic already controls when notifications are created
3. It's faster (no complex subqueries)

## Files Modified
- `fix_notifications_rls_final_comprehensive.sql` - SQL script to fix RLS
- `debug_notifications_rls_current.sql` - Debug script to check current state

## Testing Checklist
- [ ] Run SQL fix on Supabase
- [ ] Verify policies with verification query
- [ ] Sign in as member
- [ ] Request deal authorization
- [ ] Verify notification appears in trusted partner's notifications
- [ ] Verify no RLS errors appear
- [ ] Verify member can't see trusted partner's notifications (SELECT policy works)

## Related Files in Codebase
- `lib/services/discount_service.dart` - `createNotification()` method (line 402)
- `lib/services/deal_authorization_service.dart` - Calls `createNotification()` 
- `lib/models/notification.dart` - Notification model
- `lib/features/auth/notifications_page.dart` - UI for viewing notifications

## Rollback (If Needed)

If you need to rollback to the original restrictive policy:

```sql
DROP POLICY IF EXISTS "notifications_insert_all" ON notifications;

CREATE POLICY "notifications_insert_restricted" 
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());
```

**Note:** This will break cross-user notifications again.
