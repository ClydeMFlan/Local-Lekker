# Fix for Admin Deal Image Upload Issue

## Problem
When an admin (who has been authorized by a trusted partner) tries to create or edit a deal and upload an image, the upload fails with the error:
> "Failed to upload image: You are not authorized to upload images for this business. Check that the partner has allowed admin deal creation."

## Root Cause
The RLS (Row Level Security) policies for the `storage.objects` table were using incorrect array indexing with `storage.foldername()` function, causing the policy checks to fail.

## Solution

### Step 1: Apply the RLS Policy Fix
Run the SQL script `fix_admin_deal_image_upload_rls.sql` in your Supabase SQL Editor.

This script will:
1. Drop all existing deal image policies to avoid conflicts
2. Create new policies using `split_part()` for reliable path parsing
3. Set up separate policies for trusted partners and admins
4. Use correct path segment extraction (segment 2 = partner UUID)

### Step 2: Verify the Fix
Run the test script `test_admin_deal_image_upload.sql` in your Supabase SQL Editor.

Replace `'PARTNER_UUID_HERE'` with the actual partner's user ID you're testing with.

The test will check:
- ✓ Current user is an admin
- ✓ Partner has `allow_admin_deal_creation = true`
- ✓ All required storage policies exist
- ✓ Path parsing works correctly
- ✓ Policy simulation passes

### Step 3: Test in the App
1. Rebuild and run the Flutter app
2. As an admin, navigate to a trusted partner's profile
3. Verify the partner has allowed admin deal creation
4. Try to create or edit a deal and upload an image
5. Check the debug console for the following logs:
   ```
   DEBUG: Uploading image to path: deal_images/{partner-uuid}/{filename}
   DEBUG: Target partner ID: {partner-uuid}
   DEBUG: Current user ID: {admin-uuid}
   DEBUG: Is admin creating for partner: true
   DEBUG: Image uploaded successfully: {image-url}
   ```

## Technical Details

### Path Structure
Images are uploaded to: `deal_images/{partner_user_id}/{filename}`

For example: `deal_images/abc123-def456-ghi789/1234567890_image.jpg`

### Path Parsing
Using `split_part(name, '/', segment_number)`:
- Segment 1: `'deal_images'`
- Segment 2: `'{partner_user_id}'` ← This is what we need!
- Segment 3: `'{filename}'`

### Policy Logic
For admin uploads to work, ALL of these must be true:
1. User has `role = 'admin'` in the `memberships` table
2. Business has `allow_admin_deal_creation = true` in the `businesses` table
3. The `owner_member_id` in `businesses` matches the partner UUID in the upload path
4. The upload path follows the pattern: `deal_images/{partner_uuid}/{filename}`

## Files Modified
- `fix_admin_deal_image_upload_rls.sql` - The main fix
- `test_admin_deal_image_upload.sql` - Verification script
- `diagnose_admin_deal_image_permissions.sql` - Diagnostic queries
- `lib/features/auth/discount_management_page.dart` - Added debug logging

## Troubleshooting

### If upload still fails after applying the fix:

1. **Check admin role:**
   ```sql
   SELECT role FROM public.memberships WHERE user_id = auth.uid();
   ```
   Should return `'admin'`

2. **Check partner permission:**
   ```sql
   SELECT allow_admin_deal_creation 
   FROM public.businesses 
   WHERE owner_member_id = '{partner_uuid}';
   ```
   Should return `true`

3. **Check policies exist:**
   ```sql
   SELECT policyname 
   FROM pg_policies 
   WHERE tablename = 'objects' 
   AND policyname LIKE '%deal image%';
   ```
   Should return 9 policies (4 partner + 4 admin + 1 member view)

4. **Check debug logs:**
   Look for the DEBUG output in the Flutter console to see the exact path being used and any error details.

5. **Verify path format:**
   Ensure the path is `deal_images/{partner_uuid}/{filename}` and not `deal_images/{filename}` or any other format.

## Prevention
To prevent this issue in the future:
- Always use `split_part()` instead of `storage.foldername()` for path parsing in RLS policies
- Test RLS policies with actual path examples before deploying
- Use separate policies for different operations (INSERT, SELECT, UPDATE, DELETE) for better debugging
- Add comprehensive logging to upload functions
