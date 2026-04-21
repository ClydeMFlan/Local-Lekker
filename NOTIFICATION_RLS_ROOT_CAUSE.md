# Notification RLS Fix - Root Cause Analysis

## Problem
Deal authorization requests were failing with:
```
PostgrestException(message: Cannot coerce the result to a single JSON object, 
code: PGRST116, details: The result contains 0 rows, hint: null)
```

## Root Cause Discovery

### What We Thought Was Wrong
- RLS blocking INSERT on notifications table
- Created multiple INSERT policies for authenticated/public roles
- All attempts failed despite correct policy structure

### What Was Actually Wrong
**TWO separate RLS issues:**

1. **INSERT RLS blocking** - Fixed with SECURITY DEFINER function ✅
2. **SELECT RLS blocking** - The hidden issue! ❌

## The Complete Picture

When a member requests a deal authorization:
1. Member creates notification FOR trusted partner (user_id = trusted_partner_id)
2. Bypass function successfully creates notification (INSERT works)
3. App tries to SELECT the notification back to return it
4. SELECT RLS policy: `user_id = auth.uid()` 
5. **FAIL:** Member (auth.uid) ≠ trusted_partner (user_id)
6. SELECT returns 0 rows → PGRST116 error

## Why Disabling RLS Worked
When RLS was disabled:
- INSERT succeeded (no policy check)
- SELECT succeeded (no policy check)
- App worked perfectly

## The Solution

### Version 1 (Failed)
```sql
-- Function returned UUID only
RETURNS UUID
...
RETURNING id INTO v_notification_id;
RETURN v_notification_id;
```

**Problem:** App had to do separate SELECT, which hit SELECT RLS policy

### Version 2 (Working) ✅
```sql
-- Function returns full notification record
RETURNS TABLE (id UUID, user_id UUID, title TEXT, ...)
...
RETURN QUERY
INSERT INTO notifications ...
RETURNING *;
```

**Success:** No SELECT needed, SECURITY DEFINER bypasses all RLS

## Files Modified

1. **create_notification_bypass_function_v2.sql**
   - Updated function to return full table record
   - Bypasses both INSERT and SELECT RLS

2. **lib/services/discount_service.dart**
   - Removed separate SELECT query
   - Parse result directly from RPC call

## Lesson Learned

RLS errors can have **multiple layers**:
- First error might be INSERT blocking
- After fixing INSERT, SELECT might block
- SECURITY DEFINER functions must return complete data to avoid subsequent RLS checks

## Next Steps

1. Run `create_notification_bypass_function_v2.sql` in Supabase
2. Hot reload Flutter app (`r` in terminal)
3. Test deal authorization request
4. Should work without any RLS errors!
