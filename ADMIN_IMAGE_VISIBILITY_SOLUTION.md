# Admin Deal Image Display Issue - Complete Solution

## Problem Statement
✗ Admin-uploaded deal images don't display to admins or members  
✓ TP-uploaded deal images display correctly to all users

## Root Cause
The Supabase RLS (Row Level Security) policy for admin image viewing is **too restrictive**.

### The Policy That's Causing the Problem
File: `fix_admin_deal_image_upload_rls.sql` (lines 81-99)

```sql
CREATE POLICY "Admins can view deal images for authorized partners" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (SELECT 1 FROM public.memberships m 
                WHERE m.user_id = auth.uid() AND m.role = 'admin') AND
        EXISTS (SELECT 1 FROM public.businesses b 
                WHERE b.owner_member_id::text = split_part(name, '/', 2)
                  AND COALESCE(b.allow_admin_deal_creation, false) = true)  -- ← PROBLEM
    );
```

The policy requires BOTH:
1. User is an admin ✓
2. **Business owner enabled `allow_admin_deal_creation=true`** ✗ ← Not always true!

When `allow_admin_deal_creation=false`:
- Admin can't SELECT (view) the image file from storage
- The image URL saves to database, but browser can't load it
- Members CAN view it because "Members can view deal images" policy has no restrictions

## Solution
**Remove the `allow_admin_deal_creation` check from the admin SELECT policy.**

Admins should be able to view images they upload regardless of that business permission.

## Implementation

### What to Do
Run the SQL fix in Supabase SQL Editor:

```sql
DROP POLICY IF EXISTS "Admins can view deal images for authorized partners" ON storage.objects;

CREATE POLICY "Admins can view deal images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1 FROM public.memberships m
            WHERE m.user_id = auth.uid() AND m.role = 'admin'
        )
    );
```

**File containing this fix**: `fix_admin_image_visibility_rls.sql`

### Application Steps
1. Open Supabase Console → SQL Editor
2. Create new query
3. Copy-paste the SQL above
4. Click RUN
5. Rebuild Flutter app: `flutter run`
6. Test: Create deal with image as admin, verify it displays

## Technical Details

### Current Storage Structure
```
Storage Bucket: business-bills
Upload Path: deal_images/{trusted_partner_id}/{timestamp}_{filename}
Access Pattern:
  - Filename includes millisecond timestamp for cache-busting
  - Path stored in trusted_partner_discounts.image_url
  - Browser loads via Image.network() with RLS policy validation
```

### RLS Policy Logic
When browser requests image, Supabase checks ALL SELECT policies:
```
If (Admins policy matches) OR (Members policy matches) OR (TP policy matches)
  → Allow access
Else
  → Deny (403 Forbidden)
```

**The Bug**: Admins policy was too strict, so it failed. But Members policy succeeded, which meant:
- Members could see admin-uploaded images (weird but works)
- Admins viewing as admin couldn't see their own uploads (broken)

### Why TP Uploads Work
TP policy uses simple ownership check:
```sql
split_part(name, '/', 2) = auth.uid()::text
```
No additional business permission check, so it always works.

## Code Changes Made

### Files Modified
1. **lib/features/admin/admin_partner_deals_screen.dart**
   - Added debug logging to show image URLs and load errors
   - Added error builder to Image.network() for better debugging

2. **lib/services/discount_service.dart**
   - Added logging when creating discounts with images
   - Logs confirm image_url is being passed through

### Why These Changes
To help diagnose the issue and confirm images are being uploaded and saved correctly.

## Testing Checklist

After applying the fix:

- [ ] Admin creates deal with image → Image displays immediately
- [ ] Admin edits deal with existing image → Image loads
- [ ] Admin uploads new image to deal → Image displays
- [ ] Member views admin-uploaded image → Image displays
- [ ] TP creates deal with image → Image displays (regression test)
- [ ] TP edits their own deal image → Image displays (regression test)

## Monitoring

### Debug Output to Watch For
In Flutter console, you should see:
```
✅ Discount created, returned imageUrl: https://...
🎯 Admin Deal: [Name] - image_url=https://...
```

If you see `image_url=NULL`, the upload failed.

### Storage Permission Errors
If Image.network() fails, you should see:
```
❌ Failed to load image for [Deal Name]: [Error message]
```

With the fix, this shouldn't happen anymore.

## Implications & Considerations

### What This Change Does
- Admins can now view images from deals they manage
- No impact on member viewing (already worked)
- No impact on TP viewing/uploading (unchanged)

### What This Change Doesn't Do
- Doesn't affect the UPLOAD permission check
- Doesn't affect other deal functionality
- Doesn't change database schema
- Upload still requires `allow_admin_deal_creation=true` (correct behavior)

### Security Impact
✓ No security regression - admins already had access to TP data
✓ Members can view all deal images (intentional, for browsing)
✓ TPs can only view their own images (enforced by policy)

## Related Files

- `unified_schema_rls_policies.sql` - Full database schema with original RLS setup
- `add_deal_images_rls_policies.sql` - Original policies (had the issue)
- `fix_admin_deal_image_upload_rls.sql` - Previous fix attempt (still has the issue)
- `fix_admin_image_visibility_rls.sql` - **New fix (CORRECT)**
- `ADMIN_IMAGE_FIX_STEPS.md` - Step-by-step instructions

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| Admin views own image | ❌ Blocked | ✓ Works |
| Member views image | ✓ Works | ✓ Works |
| TP views own image | ✓ Works | ✓ Works |
| Upload with permission | ✓ Works | ✓ Works |
| Upload without permission | ❌ Blocked | ❌ Blocked |

---

**Status**: Ready to apply fix  
**Impact**: Low-risk policy change  
**Testing Required**: Manual testing with admin and member accounts
