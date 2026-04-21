# Admin Image Display Fix - Checklist

## ✓ Pre-Fix Checklist

Before applying the fix:

- [ ] Read `ADMIN_IMAGE_FIX_STEPS.md` for step-by-step instructions
- [ ] Have access to Supabase Console
- [ ] Have the Flutter app source code open
- [ ] Identify a test user who is an admin
- [ ] Identify a test trusted partner
- [ ] Identify a test member account

## ✓ Applying the Fix

### Step 1: Copy SQL from fix_admin_image_visibility_rls.sql

File location: `c:\Users\clyde\local_lekker\fix_admin_image_visibility_rls.sql`

Lines to copy (1-57):
```
-- Fix: Allow admins to view deal images they upload
...
SELECT ... FROM pg_policies...;
```

- [ ] Copied the SQL
- [ ] Ready to paste

### Step 2: Open Supabase SQL Editor

- [ ] Logged into Supabase Console
- [ ] Selected correct project
- [ ] Opened SQL Editor
- [ ] Created new query

### Step 3: Execute the SQL

- [ ] Pasted SQL into editor
- [ ] Reviewed the commands:
  - [ ] `DROP POLICY` statement
  - [ ] `CREATE POLICY` statement
  - [ ] `SELECT` verification query
- [ ] Clicked RUN button

### Step 4: Verify Execution

Expected output:
```
DROP POLICY    ✓ Success
CREATE POLICY  ✓ Success
SELECT Results: (shows policies)
```

Check:
- [ ] No errors in output
- [ ] "DROP POLICY" succeeded
- [ ] "CREATE POLICY" succeeded
- [ ] Verification query returned results

### Step 5: Verify Policy Was Created

Run this verification query:
```sql
SELECT policyname, cmd 
FROM pg_policies 
WHERE tablename = 'objects' 
AND policyname LIKE '%Admin%' 
AND cmd = 'SELECT';
```

Expected result:
- [ ] Shows "Admins can view deal images" (NOT "for authorized partners")

## ✓ Rebuild Flutter App

### Step 6: Rebuild the App

Terminal in VS Code:
- [ ] Stop flutter run (Ctrl+C)
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter run`
- [ ] Wait for app to compile and launch

Or hot reload:
- [ ] If app is running, press 'R' for hot reload
- [ ] Or press 'r' for cold restart

Expected:
- [ ] App builds without errors
- [ ] App launches successfully
- [ ] Console shows no error messages

## ✓ Testing: Admin Image Upload

### Test 1: Admin Creates Deal with Image

**As Admin User**:

1. [ ] Open app
2. [ ] Verify logged in as admin
3. [ ] Navigate to: Admin → Trusted Partners → [Select a Partner]
4. [ ] Click "Deals" tab
5. [ ] Click "Add Deal" or "Edit Existing Deal"
6. [ ] Fill in deal details:
   - [ ] Select deal type (e.g., Percentage)
   - [ ] Enter deal name
   - [ ] Enter item name and price
   - [ ] Enter discount amount
7. [ ] Scroll down to image section
8. [ ] Click "Upload Image"
9. [ ] Select an image from your device
10. [ ] Click "Save Deal" button

Check console output:
- [ ] Look for: `📝 Creating discount with imageUrl: https://...`
- [ ] Look for: `✅ Discount created, returned imageUrl: ...`

Expected UI result:
- [ ] Success message: "Deal created/updated successfully"
- [ ] Deal appears in list
- [ ] **Image thumbnail displays immediately** ← KEY TEST

Result:
- [ ] ✓ PASS - Image displays
- [ ] ✗ FAIL - Image doesn't display (may indicate policy not applied)

### Test 2: Admin Edits Deal with Image

1. [ ] Still logged in as admin
2. [ ] Tap the deal you just created to edit
3. [ ] Make a small change (e.g., name)
4. [ ] DON'T change image (leave existing)
5. [ ] Click "Save Deal"

Check:
- [ ] Image still displays in list
- [ ] No console errors

Result:
- [ ] ✓ PASS - Existing image preserved
- [ ] ✗ FAIL - Image disappeared

## ✓ Testing: Member Views Admin Image

### Test 3: Member Sees Admin-Uploaded Image

**As Member User**:

1. [ ] Logout (or use different device/account)
2. [ ] Login as a test member
3. [ ] Navigate to: Home → Browse Deals
4. [ ] Find the trusted partner that has the admin-uploaded image
5. [ ] Expand/view the deals for that partner

Expected result:
- [ ] ✓ PASS - Image displays in deal card
- [ ] ✗ FAIL - Image doesn't display (RLS issue)
- [ ] ⚠️ WARNING - Image placeholder shows (might be cache issue)

Check console:
- [ ] No 403 errors
- [ ] No RLS restriction messages

## ✓ Testing: TP Upload Still Works (Regression Test)

### Test 4: TP Creates Deal with Image

**As Trusted Partner User**:

1. [ ] Logout (or use different account)
2. [ ] Login as the trusted partner
3. [ ] Navigate to: Deals Management Page (usually first screen for TP)
4. [ ] Click "Add Deal"
5. [ ] Select deal type
6. [ ] Fill in details
7. [ ] Upload an image
8. [ ] Save deal

Expected result:
- [ ] ✓ PASS - Deal created, image displays
- [ ] ✗ FAIL - Upload fails (regression!)

This tests that we didn't break TP functionality.

## ✓ Testing: Edit TP Deal with Image

### Test 5: TP Edits Their Deal

1. [ ] Still logged in as TP
2. [ ] Find the deal you just created
3. [ ] Click edit
4. [ ] Upload a DIFFERENT image
5. [ ] Save

Expected result:
- [ ] ✓ PASS - New image displays
- [ ] ✗ FAIL - Old image still shows (database not updating)

## ✓ Console Output Checklist

Expected outputs during testing:

**During Admin Upload**:
```
📝 Creating discount with imageUrl: https://...
✅ Discount created, returned imageUrl: https://...
🎯 Admin Deal: [Name] - image_url=https://...
```

**During Member Browse**:
```
✅ Browse Deals: Filtered to X available deals...
[No errors about image loading]
```

**If Fix Not Applied**:
```
❌ Failed to load image for [Deal Name]: (403 Forbidden)
[Image loads but admin can't see it]
```

Checks:
- [ ] Admin upload shows image URLs in console
- [ ] No 403 errors for admins
- [ ] No RLS errors in console
- [ ] Member view has no image loading errors

## ✓ Edge Case Testing

### Test 6: Image Display with Cache Busting

1. [ ] Admin uploads image
2. [ ] Check that cache-buster is in URL:
   ```
   https://...deal_images/[uuid]/[timestamp]_image.jpg?t=[timestamp]
   ```
3. [ ] Verify URL format is correct

Expected:
- [ ] ✓ PASS - Cache buster parameter present
- [ ] ✗ FAIL - Missing query parameter

### Test 7: Large Image Upload

1. [ ] Try uploading a larger image (5MB)
2. [ ] Verify it uploads successfully
3. [ ] Verify it displays

Expected:
- [ ] ✓ PASS - Handles large files
- [ ] ✗ FAIL - Upload timeout or error

### Test 8: Multiple Images

1. [ ] Create multiple deals with different images
2. [ ] Verify each displays correctly
3. [ ] Verify no image is mixed up with another deal

Expected:
- [ ] ✓ PASS - Each deal shows correct image
- [ ] ✗ FAIL - Images are swapped or duplicated

## ✓ Rollback Plan (If Needed)

If the fix breaks something:

1. [ ] Have access to Supabase SQL Editor
2. [ ] Run the reversal SQL:
   ```sql
   DROP POLICY IF EXISTS "Admins can view deal images" ON storage.objects;
   
   -- Recreate the old policy (less efficient but known to partially work)
   CREATE POLICY "Admins can view deal images for authorized partners" ON storage.objects
       FOR SELECT USING (
           bucket_id = 'business-bills' AND
           name LIKE 'deal_images/%' AND
           EXISTS (SELECT 1 FROM public.memberships m 
                   WHERE m.user_id = auth.uid() AND m.role = 'admin') AND
           EXISTS (SELECT 1 FROM public.businesses b 
                   WHERE b.owner_member_id::text = split_part(name, '/', 2)
                     AND COALESCE(b.allow_admin_deal_creation, false) = true)
       );
   ```
3. [ ] Rebuild Flutter app

## ✓ Post-Fix Documentation

After fix is confirmed working:

- [ ] Date applied: ___________
- [ ] Tested by: ___________
- [ ] Issues found: ___________
- [ ] All tests passed: YES / NO
- [ ] Ready for production: YES / NO

### Sign-off

- [ ] Admin team confirms images display
- [ ] Member team confirms images visible
- [ ] TP team confirms functionality not broken
- [ ] No 403 errors in production
- [ ] Performance is acceptable

## ✓ Troubleshooting Guide

### Issue: Images Still Don't Display

[ ] Check 1: Policy was applied
```
SELECT policyname FROM pg_policies WHERE policyname LIKE '%Admin%';
```
Should return "Admins can view deal images" (NOT "for authorized partners")

[ ] Check 2: Flutter app was rebuilt
- Is the old binary still running?
- Try: `flutter clean` then `flutter run`

[ ] Check 3: Image URL in database
```
SELECT image_url FROM trusted_partner_discounts WHERE id = '[deal_id]';
```
Should show a URL, not NULL

[ ] Check 4: Image file exists in storage
- Supabase Console → Storage → business-bills → deal_images
- Should see folders with partner IDs

### Issue: 403 Forbidden Error

[ ] RLS policy still blocked the request
- Wait 30 seconds for Supabase cache to refresh
- Try hard refresh (Ctrl+F5)
- Rebuild Flutter app

[ ] Wrong policy applied
- Verify policy name: "Admins can view deal images"
- Not: "Admins can view deal images for authorized partners"

### Issue: Only Member View Works (Not Admin)

[ ] The new admin policy isn't being used
- Check if old policy still exists
- May need to manually delete if DROP didn't work
- Rerun the fix SQL

### Issue: Upload Fails for Admin

[ ] This is a DIFFERENT issue (not the focus of this fix)
- Check allow_admin_deal_creation flag on business
- This requires admin permission, which is correct behavior

## ✓ Final Verification

Once all tests pass:

- [ ] Admin uploads image → Admin sees it ✓
- [ ] Admin uploads image → Member sees it ✓
- [ ] TP uploads image → Still works ✓
- [ ] No 403 errors in console ✓
- [ ] No RLS errors in logs ✓
- [ ] Cache-busting working ✓
- [ ] Large files work ✓
- [ ] Multiple images work ✓

## ✓ Sign-Off

- [ ] All tests passed
- [ ] Ready to close issue
- [ ] Date: ___________
- [ ] Verified by: ___________
