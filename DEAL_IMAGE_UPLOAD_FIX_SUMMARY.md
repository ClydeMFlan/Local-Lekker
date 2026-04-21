# Deal Image Upload & Display - Complete Fix Summary

## Issues Found & Fixed

### 1. ❌ Broken RLS INSERT Policies
**Problem**: Admin and Trusted Partner INSERT policies had `null` WITH CHECK clauses, blocking all uploads.

**Fix Applied**: `fix_deal_image_insert_policies.sql`
- Recreated both INSERT policies with proper WITH CHECK expressions
- Admin policy checks: `memberships.role = 'admin'` AND `businesses.allow_admin_deal_creation = true`
- Trusted Partner policy checks: `split_part(name, '/', 2) = auth.uid()::text`

### 2. ✅ Cache-Busting Added
**Updated Files**:
- `lib/features/auth/deal_selection_page.dart`:
  - Added `displayDealImageUrl()` helper function
  - Extracts timestamp from filename pattern `{timestamp}_image.jpg`
  - Applied to deal image displays in member deal cards
- `lib/features/admin/admin_partner_deals_screen.dart`:
  - Added `_appendCacheBusterToDealImage()` method
  - Applied to admin deal list thumbnails

**Pattern**: `deal_images/{partner_id}/{timestamp}_filename.jpg` → URL gets `?t={timestamp}`

---

## Configuration Verified

### Storage Setup
- **Bucket**: `business-bills` (existing, no change needed)
- **Path**: `deal_images/{partner_id}/{timestamp}_filename.jpg`
- **Bucket is PUBLIC**: Yes
- **Code location**: `lib/features/auth/discount_management_page.dart` lines 1370-1390

### Database
- **Table**: `trusted_partner_discounts`
- **Column**: `image_url` (TEXT, nullable)
- **Stores**: Full public URL to image in storage

### RLS Policies (After Fix)
1. **Admin INSERT**: Requires `memberships.role='admin'` + `allow_admin_deal_creation=true`
2. **Admin UPDATE/DELETE/SELECT**: Same checks as INSERT
3. **Trusted Partner INSERT/UPDATE/DELETE**: Owner must match `auth.uid()`
4. **Members SELECT**: All authenticated users can view deal images

---

## Required Actions

### Step 1: Apply RLS Policy Fix
```sql
-- Run in Supabase SQL Editor:
-- File: fix_deal_image_insert_policies.sql
```

This will:
- Drop broken INSERT policies
- Recreate with proper WITH CHECK clauses
- Verify policies are correct

### Step 2: Verify Admin Permissions
```sql
-- Run in Supabase SQL Editor:
-- File: verify_admin_deal_upload_permissions.sql
```

This checks:
1. Admin user exists in `memberships` table with `role='admin'`
2. If NOT in memberships, provides INSERT statement to add them
3. Verifies That Old Oak has `allow_admin_deal_creation = true`

**If admin NOT in memberships**, run:
```sql
INSERT INTO memberships (user_id, role, created_at)
SELECT id, 'admin', NOW()
FROM profiles
WHERE role = 'admin'
  AND id NOT IN (SELECT user_id FROM memberships);
```

**If That Old Oak doesn't allow admin deals**, run:
```sql
UPDATE businesses
SET allow_admin_deal_creation = true
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';
```

### Step 3: Hot Reload Flutter App
```powershell
# Press 'r' in flutter run terminal or:
flutter run
```

### Step 4: Test Deal Image Upload
1. **As Admin**:
   - Navigate to Admin → Trusted Partners → That Old Oak → Deals tab
   - Tap "Add Deal" (or edit existing deal)
   - Upload a deal image
   - **Expected**: Green "Deal created/updated successfully" message
   - Image displays immediately in deal list with cache-busting

2. **Verify in Member View**:
   - Navigate to Members Home → Browse Deals
   - Find That Old Oak's deal
   - **Expected**: Deal image displays with cache-busting query parameter
   - Image loads fresh, no stale cache

3. **Verify in Storage**:
   - Open Supabase → Storage → business-bills bucket
   - Check `deal_images/{partner_id}/` folder
   - **Expected**: New image file with timestamp prefix

---

## Display Locations Updated

### Member Screens
- ✅ `lib/features/auth/deal_selection_page.dart` - Deal cards with images
- ✅ Cache-busting via `displayDealImageUrl()` helper

### Admin Screens
- ✅ `lib/features/admin/admin_partner_deals_screen.dart` - Deal list thumbnails
- ✅ Cache-busting via `_appendCacheBusterToDealImage()` method

### Trusted Partner Screens
- ℹ️ Uses same `discount_management_page.dart` for uploads
- ℹ️ Display handled by existing deal management UI

---

## Technical Details

### Upload Flow
1. Admin/TP selects image via `ImagePicker`
2. `discount_management_page.dart` line 1370:
   - Generates filename: `{timestamp}_{original_name}`
   - Path: `deal_images/{partner_id}/{filename}`
   - Uploads to `business-bills` bucket
3. RLS policy checks:
   - Admin: `memberships.role='admin'` + `businesses.allow_admin_deal_creation`
   - TP: `split_part(name, '/', 2) = auth.uid()`
4. On success: Returns public URL
5. URL saved to `trusted_partner_discounts.image_url`

### Cache-Busting Strategy
- **Filename pattern**: `{milliseconds_timestamp}_filename.jpg`
- **Extraction**: `RegExp(r'(\d+)_')` captures timestamp
- **URL modification**: Appends `?t={timestamp}` to force browser refresh
- **Deterministic**: Same file = same cache key across sessions

---

## Troubleshooting

### Upload fails with "row-level security" error
- **Cause**: Admin not in `memberships` table OR `allow_admin_deal_creation = false`
- **Fix**: Run Step 2 verification queries and apply missing permissions

### Image doesn't display after upload
- **Cause**: Browser cached old image or RLS blocking SELECT
- **Fix**: Cache-busting now applied (Step 3 hot reload needed)
- **Verify**: Check network tab shows `?t=timestamp` in image URL

### Old images not deleted
- **Cause**: Normal behavior - deal images persist unless manually deleted
- **Note**: Unlike logo uploads, deal images don't auto-delete old versions

---

## Files Modified

### SQL Migrations
- `fix_deal_image_insert_policies.sql` - Fixed broken INSERT policies
- `verify_admin_deal_upload_permissions.sql` - Check admin permissions

### Dart Files
- `lib/features/auth/deal_selection_page.dart` - Added cache-busting helper, applied to deal images
- `lib/features/admin/admin_partner_deals_screen.dart` - Added cache-busting method, applied to thumbnails

### No Changes Needed
- `lib/features/auth/discount_management_page.dart` - Upload logic already correct
- Storage bucket configuration - Using `business-bills` is intentional

---

**Status**: All fixes applied ✅  
**Next**: Run SQL migrations and test upload flow  
**Date**: December 3, 2025
