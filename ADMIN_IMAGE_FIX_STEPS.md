# Step-by-Step Fix: Admin Deal Image Display Issue

## Quick Summary
**Issue**: Admin-uploaded deal images don't display
**Cause**: RLS policy requires `allow_admin_deal_creation=true` for admins to VIEW images
**Fix**: Remove that restriction from the admin SELECT policy

## Steps to Apply the Fix

### Step 1: Open Supabase SQL Editor
1. Go to [Supabase Console](https://app.supabase.com)
2. Select your project
3. Go to SQL Editor (left sidebar)
4. Create new query

### Step 2: Copy & Paste the Fix
Copy this SQL and paste it into the SQL Editor:

```sql
-- Fix: Allow admins to view deal images they upload
-- Drop the overly-restrictive admin SELECT policy
DROP POLICY IF EXISTS "Admins can view deal images for authorized partners" ON storage.objects;

-- Create a new, more permissive admin policy
-- Admins can view ANY deal image (regardless of allow_admin_deal_creation)
CREATE POLICY "Admins can view deal images" ON storage.objects
    FOR SELECT USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1
            FROM public.memberships m
            WHERE m.user_id = auth.uid()
              AND m.role = 'admin'
        )
    );

-- Verify the fix
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN cmd = 'SELECT' THEN 'View policy ✓'
        WHEN cmd = 'INSERT' THEN 'Upload policy ✓'
        ELSE 'Other'
    END as policy_type
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (policyname LIKE '%deal image%' OR policyname LIKE '%Admin%')
ORDER BY cmd DESC;
```

### Step 3: Execute the Query
1. Click the "RUN" button (or Ctrl+Enter)
2. You should see:
   - "DROP POLICY" succeeded
   - "CREATE POLICY" succeeded
   - Verification results showing the policies

### Step 4: Verify the Results
The verification query should return something like:

```
policyname                                    | cmd    | policy_type
---------------------------------------------------+--------+----------------
Admins can upload deal images...              | INSERT | Upload policy ✓
Admins can view deal images                   | SELECT | View policy ✓
Members can view deal images                  | SELECT | View policy ✓
Trusted partners can upload deal images       | INSERT | Upload policy ✓
Trusted partners can view deal images         | SELECT | View policy ✓
```

### Step 5: Rebuild Flutter App
1. In VS Code terminal where flutter is running, press: `r` (for hot reload)
   - Or stop and run: `flutter run`

### Step 6: Test in App
1. **As Admin**:
   - Go to: Admin → Trusted Partners → [Select Partner] → Deals tab
   - Create new deal or edit existing
   - Upload an image
   - **Result**: Image should display in thumbnail immediately ✓

2. **As Member**:
   - Go to: Home → Browse Deals
   - Find the partner with the admin-uploaded image
   - **Result**: Image should display in deal card ✓

3. **As TP** (to ensure we didn't break existing functionality):
   - Go to your Deals management page
   - Create/edit deal with image
   - **Result**: Image should display as before ✓

## Troubleshooting

### If Images Still Don't Display

#### Check 1: Verify Policies Were Applied
Run this in Supabase SQL Editor:

```sql
SELECT 
    policyname,
    cmd,
    CASE 
        WHEN policyname LIKE '%Admin%' AND cmd='SELECT' THEN 'ADMIN VIEW'
        WHEN policyname LIKE '%Member%' AND cmd='SELECT' THEN 'MEMBER VIEW'
        ELSE policyname
    END as policy_type
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND bucket_id = 'business-bills'
ORDER BY policyname;
```

**Expected**: Should show at least:
- "Admins can view deal images" (SELECT)
- "Members can view deal images" (SELECT)
- "Trusted partners can view deal images" (SELECT)

#### Check 2: Verify Image URL in Database
Run this query:

```sql
SELECT 
    id,
    name,
    image_url,
    trusted_partner_id,
    CASE 
        WHEN image_url IS NULL THEN '❌ No image URL'
        WHEN image_url LIKE '%deal_images%' THEN '✓ Image URL exists'
        ELSE '⚠️ Unexpected URL format'
    END as image_status
FROM trusted_partner_discounts
WHERE image_url IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;
```

**Expected**: Should show recent deals with image URLs

#### Check 3: Verify Storage Files Exist
In Supabase Console → Storage:
1. Click "business-bills" bucket
2. Look for "deal_images" folder
3. You should see subfolders with partner UUIDs
4. Each should contain image files

#### Check 4: Check App Debug Logs
When you run the app, check the console output for:

```
🎯 Admin Deal: [Deal Name] - image_url=https://...
```

If this shows `image_url=NULL`, the image wasn't saved to the database.

## File References

- **SQL Fix**: `/fix_admin_image_visibility_rls.sql`
- **Diagnosis Guide**: `/ADMIN_IMAGE_VISIBILITY_FIX.md`
- **Modified App Files**:
  - `lib/features/admin/admin_partner_deals_screen.dart` - Added error logging
  - `lib/services/discount_service.dart` - Added URL logging

## What Changed

### Before (Broken Policy)
```sql
-- Admins could ONLY view images if:
-- 1. User is admin AND
-- 2. Business has allow_admin_deal_creation=true
CREATE POLICY "Admins can view deal images for authorized partners" ON storage.objects
    FOR SELECT USING (
        ... AND allow_admin_deal_creation = true  -- ← This blocks viewing!
    );
```

### After (Fixed Policy)
```sql
-- Admins can view ANY deal image
-- The "allow_admin_deal_creation" check only applies to UPLOAD
CREATE POLICY "Admins can view deal images" ON storage.objects
    FOR SELECT USING (
        ... -- No business permission check
    );
```

## Questions?

- Check the console output for error messages
- Ensure you're logged in with the correct role
- Verify `allow_admin_deal_creation` is enabled for the partner (if needed for uploads)
- Check that image files exist in Supabase Storage
