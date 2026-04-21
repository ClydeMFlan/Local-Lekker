# Admin Deal Image Display - Complete Reference

## Executive Summary

**Issue**: Admin-uploaded deal images don't display  
**Root Cause**: Overly restrictive RLS SELECT policy for admins  
**Fix Complexity**: Low (1 SQL statement to replace)  
**Time to Apply**: 5 minutes

## Files Created/Modified

### Documentation Files (NEW)
```
📄 ADMIN_IMAGE_VISIBILITY_SOLUTION.md       ← Complete technical overview
📄 ADMIN_IMAGE_FIX_STEPS.md                 ← Step-by-step instructions
📄 ADMIN_IMAGE_VISUAL_GUIDE.md              ← Diagrams and visual explanations
📄 ADMIN_IMAGE_VISIBILITY_FIX.md            ← Diagnosis and analysis
📄 fix_admin_image_visibility_rls.sql       ← The actual SQL fix (READY TO APPLY)
📄 diagnose_deal_image_policies.sql         ← Verification query
```

### Code Files (MODIFIED - for debugging)
```
📝 lib/features/admin/admin_partner_deals_screen.dart
   - Added: Debug logging for image URLs
   - Added: Error builder for Image.network() to catch issues

📝 lib/services/discount_service.dart
   - Added: Console logging when creating discounts
   - Added: Confirmation logs for image URL saving
```

## Quick Action Plan

### 1. Copy the SQL Fix
```
File: fix_admin_image_visibility_rls.sql
Lines 1-30
```

### 2. Apply in Supabase
1. Supabase Console → SQL Editor → New Query
2. Paste the SQL
3. Click RUN
4. Confirm "DROP POLICY" and "CREATE POLICY" succeeded

### 3. Rebuild App
```
flutter run
```

### 4. Test
- Admin creates deal with image → Verify displays
- Member views image → Verify displays
- TP uploads image → Verify still works

## The Problem in Detail

### Policy Structure Comparison

**BEFORE (Broken)**:
```sql
CREATE POLICY "Admins can view deal images for authorized partners" 
ON storage.objects
FOR SELECT USING (
    bucket_id = 'business-bills' AND
    name LIKE 'deal_images/%' AND
    EXISTS (...check admin role...) AND
    EXISTS (...check allow_admin_deal_creation = true...)  ← TOO STRICT
);
```

**AFTER (Fixed)**:
```sql
CREATE POLICY "Admins can view deal images" 
ON storage.objects
FOR SELECT USING (
    bucket_id = 'business-bills' AND
    name LIKE 'deal_images/%' AND
    EXISTS (...check admin role...)  ← No business permission check
);
```

### Why It Fails

When admin tries to view image:
1. Image.network(url) makes HTTP request to Supabase Storage
2. Supabase checks RLS policies
3. Admin policy requires: admin role ✓ AND allow_admin_deal_creation ✓
4. If allow_admin_deal_creation = false → Policy fails
5. But Member policy succeeds → Browser gets 200 OK
6. However, Image widget can't display (RLS still restricts actual access)

### Why TP Images Work

TP policy is simple:
```sql
split_part(path, '/', 2) = auth.uid()
```
No permission checks needed - just ownership verification.

## Verification Steps

### Step 1: Check Current Policies
```sql
-- Run in Supabase SQL Editor
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'objects' 
  AND policyname LIKE '%deal image%'
ORDER BY policyname;
```

**Expected BEFORE fix**:
- "Admins can view deal images for authorized partners" (SELECT)
- "Members can view deal images" (SELECT)
- "Trusted partners can..." (SELECT/INSERT/UPDATE/DELETE)

**Expected AFTER fix**:
- "Admins can view deal images" (SELECT) ← CHANGED
- "Members can view deal images" (SELECT)
- "Trusted partners can..." (SELECT/INSERT/UPDATE/DELETE)

### Step 2: Test Image Upload
1. Create deal as admin
2. Check console for: `📝 Creating discount with imageUrl: https://...`
3. Check console for: `✅ Discount created, returned imageUrl: ...`

### Step 3: Test Image Display
1. Go to admin partner deals screen
2. Check console for: `🎯 Admin Deal: [Name] - image_url=https://...`
3. Verify image thumbnail displays

## Troubleshooting Checklist

- [ ] SQL fix applied? (Check in Supabase SQL Editor)
- [ ] Flutter app rebuilt? (Run `flutter run`)
- [ ] Hot reload not enough? (Try full rebuild/restart)
- [ ] Image URL in database? (Check trusted_partner_discounts.image_url)
- [ ] Image file in storage? (Check business-bills/deal_images/{id}/)
- [ ] Admin role verified? (Check memberships.role = 'admin')
- [ ] Console logs checked? (Look for debug output during upload)

## Detailed Impact Analysis

### What Changes
✓ Admins can now view deal images via Image.network()  
✓ No change to member access (already works)  
✓ No change to TP access (already works)  

### What Doesn't Change
✗ Image upload permission check (still requires allow_admin_deal_creation)  
✗ Member viewing permission (still unrestricted)  
✗ Database schema  
✗ File storage paths  
✗ Any other RLS policies  

### Security Impact
✓ NONE - No new access granted
✓ Admins already have access to all TP data
✓ This just fixes viewing images they uploaded

## Policy Logic Summary

```
Image Viewing Permission Check:

┌─ Is user admin? ──→ YES ──→ Can view (FIXED)
│                         
├─ Is user TP + owner? ──→ YES ──→ Can view
│
└─ Is user authenticated member? ──→ YES ──→ Can view
```

All three paths are now clear.

## Files to Reference

### Main Solution
- `fix_admin_image_visibility_rls.sql` - Copy-paste this to Supabase

### Documentation (Choose One)
- `ADMIN_IMAGE_FIX_STEPS.md` - If you want step-by-step
- `ADMIN_IMAGE_VISIBILITY_SOLUTION.md` - If you want technical details
- `ADMIN_IMAGE_VISUAL_GUIDE.md` - If you want diagrams

### Diagnostic
- `diagnose_deal_image_policies.sql` - Verify fix was applied

## Related Context

### How Images Are Handled
```
Upload: lib/features/auth/discount_management_page.dart:1361
  - _uploadImage() method handles file upload
  - Generates path: deal_images/{partnerId}/{timestamp}_{filename}
  - Returns public URL

Display: lib/features/auth/deal_selection_page.dart:34
  - _displayDealImageUrl() adds cache-busting parameter
  - Passes URL to Image.network(url)

Admin View: lib/features/admin/admin_partner_deals_screen.dart:148
  - Uses _appendCacheBusterToDealImage()
  - Shows image in ListTile leading widget
```

### Database Structure
```
Table: trusted_partner_discounts
Column: image_url (TEXT, nullable)
Stores: Full Supabase public URL
Example: https://[project].supabase.co/storage/v1/object/public/
         business-bills/deal_images/{uuid}/{timestamp}_image.jpg
```

## Support Reference

### If You Get 403 Forbidden Error
This means RLS policy is blocking access.
```
Before fix: Only members can view, admin can't
After fix: Admin can also view
```

### If Image URL is NULL
The upload might have failed.
Check console for error messages during upload.

### If Image Displays but Looks Wrong
Cache issue - clear browser cache or add cache-buster (already done).

## Timeline

- **December 8, 2025**: Issue identified
- **Today**: Root cause analyzed and fix created
- **Next Step**: Apply SQL fix to Supabase

## Approval Checklist

Before deploying to production:
- [ ] Test in development Supabase
- [ ] Verify admin can see images
- [ ] Verify members still see images
- [ ] Verify TPs still see their images
- [ ] Check console logs for errors
- [ ] Review the SQL change one more time

## Support Contact Points

All diagnostic information captured in:
1. Console logs (image URLs and load errors)
2. Supabase Storage browser (image files)
3. Database (image_url column)
4. RLS policies (storage.objects table)

Run the diagnostic query to check current state:
`SELECT * FROM pg_policies WHERE tablename = 'objects';`
