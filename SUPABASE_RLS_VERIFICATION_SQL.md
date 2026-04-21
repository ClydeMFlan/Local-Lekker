# Complete Supabase RLS Policy Verification for Admin Deal Images

## Run This SQL in Supabase SQL Editor to Verify Everything

```sql
-- ============================================================================
-- COMPLETE VERIFICATION SUITE FOR ADMIN DEAL IMAGE UPLOAD
-- ============================================================================

-- Run each section and verify the results match expectations

-- ============================================================================
-- 1. DATABASE TABLE VERIFICATION
-- ============================================================================

-- 1.1 Check trusted_partner_discounts table has image_url column
SELECT 
    column_name,
    data_type,
    is_nullable,
    CASE 
        WHEN column_name = 'image_url' THEN '✅ Column exists'
        ELSE '❌ Wrong column'
    END as status
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'trusted_partner_discounts'
  AND column_name = 'image_url';

-- 1.2 Check some sample discounts with images
SELECT 
    id,
    name,
    image_url,
    trusted_partner_id,
    business_id,
    created_at,
    CASE 
        WHEN image_url LIKE '%deal_images%' THEN '✅ Valid image URL'
        WHEN image_url IS NULL THEN '⚠️ No image'
        ELSE '❌ Invalid URL format'
    END as status
FROM trusted_partner_discounts
WHERE is_active = true
ORDER BY created_at DESC
LIMIT 10;

-- 1.3 Verify businesses table has allow_admin_deal_creation flag
SELECT 
    id,
    name,
    owner_member_id,
    allow_admin_deal_creation,
    CASE 
        WHEN allow_admin_deal_creation = true THEN '✅ Admin allowed'
        WHEN allow_admin_deal_creation = false THEN '❌ Admin not allowed'
        ELSE '❓ Unknown'
    END as admin_status
FROM businesses
LIMIT 5;

-- ============================================================================
-- 2. MEMBERSHIPS TABLE VERIFICATION
-- ============================================================================

-- 2.1 Check admin user exists in memberships
SELECT 
    user_id,
    role,
    created_at,
    CASE 
        WHEN role = 'admin' THEN '✅ Admin exists'
        ELSE '❌ Not admin'
    END as status
FROM memberships
WHERE role = 'admin'
LIMIT 5;

-- ============================================================================
-- 3. DATABASE RLS POLICIES VERIFICATION
-- ============================================================================

-- 3.1 Check trusted_partner_discounts RLS policies
SELECT 
    policyname,
    cmd,
    permissive,
    CASE 
        WHEN policyname LIKE '%view%' AND cmd = 'SELECT' THEN '✅ View policy'
        WHEN policyname LIKE '%manage%' AND cmd = 'ALL' THEN '✅ Manage policy'
        WHEN cmd = 'INSERT' THEN '✅ Create policy'
        ELSE 'Other'
    END as policy_type,
    qual::text as condition_preview
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'trusted_partner_discounts'
ORDER BY cmd, policyname;

-- 3.2 Verify members can SELECT all discounts
SELECT 
    policyname,
    'Members can view all discounts' as description,
    CASE 
        WHEN policyname = 'Members can view all discounts' 
             AND cmd = 'SELECT' 
        THEN '✅ Policy correct'
        ELSE '❌ Policy missing or wrong'
    END as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'trusted_partner_discounts'
  AND policyname = 'Members can view all discounts';

-- ============================================================================
-- 4. STORAGE BUCKET VERIFICATION
-- ============================================================================

-- 4.1 Check business-bills bucket exists and is public
SELECT 
    id,
    name,
    public,
    file_size_limit,
    CASE 
        WHEN name = 'business-bills' AND public = true THEN '✅ Bucket is public'
        WHEN name = 'business-bills' AND public = false THEN '❌ Bucket is private!'
        ELSE '❌ Wrong bucket'
    END as bucket_status
FROM storage.buckets
WHERE name = 'business-bills';

-- 4.2 Check deal image files exist in storage
SELECT 
    name as file_path,
    bucket_id,
    owner,
    created_at,
    CASE 
        WHEN name LIKE 'deal_images/%' THEN '✅ Valid path'
        ELSE '❌ Wrong path'
    END as path_status,
    CASE 
        WHEN LENGTH(name) > 0 THEN '✅ File exists'
        ELSE '❌ No file'
    END as file_status
FROM storage.objects
WHERE bucket_id = 'business-bills'
  AND name LIKE 'deal_images/%'
ORDER BY created_at DESC
LIMIT 10;

-- ============================================================================
-- 5. STORAGE RLS POLICIES VERIFICATION
-- ============================================================================

-- 5.1 Check all deal image RLS policies exist
SELECT 
    policyname,
    cmd,
    permissive,
    CASE 
        WHEN policyname = 'Members can view deal images' 
             AND cmd = 'SELECT' THEN '✅ Members view policy'
        WHEN policyname = 'Admins can manage deal images' 
             AND cmd = 'ALL' THEN '✅ Admin manage policy'
        WHEN policyname = 'Admins can view deal images'
             AND cmd = 'SELECT' THEN '✅ Admin view policy'
        WHEN policyname LIKE '%Trusted partner%'
             AND cmd = 'INSERT' THEN '✅ TP upload policy'
        ELSE 'Other'
    END as policy_status
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname LIKE '%deal image%'
ORDER BY cmd, policyname;

-- 5.2 Verify Members can view deal images policy details
SELECT 
    policyname,
    cmd,
    qual::text as select_condition,
    CASE 
        WHEN policyname = 'Members can view deal images'
             AND cmd = 'SELECT'
             AND qual::text LIKE '%deal_images%'
        THEN '✅ Policy is correct'
        ELSE '❌ Policy needs review'
    END as status
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname = 'Members can view deal images';

-- 5.3 Verify Admins can upload deal images policy
SELECT 
    policyname,
    cmd,
    with_check::text as insert_condition,
    CASE 
        WHEN with_check::text LIKE '%admin%'
             AND with_check::text LIKE '%allow_admin_deal_creation%'
        THEN '✅ Admin upload policy correct'
        ELSE '⚠️ Policy needs review'
    END as status
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND policyname = 'Admins can manage deal images'
  AND cmd = 'ALL';

-- ============================================================================
-- 6. INTEGRATION VERIFICATION
-- ============================================================================

-- 6.1 Check if any admin can currently upload to this business
-- Replace 'BUSINESS_UUID_HERE' with actual business ID
WITH admin_check AS (
    SELECT 
        m.user_id,
        m.role,
        'Admin found' as admin_status
    FROM memberships m
    WHERE m.role = 'admin'
    LIMIT 1
)
SELECT 
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id,
    b.allow_admin_deal_creation,
    ac.admin_status,
    CASE 
        WHEN ac.admin_status = 'Admin found' 
             AND b.allow_admin_deal_creation = true
        THEN '✅ Admin CAN upload to this business'
        WHEN ac.admin_status = 'Admin found' 
             AND b.allow_admin_deal_creation = false
        THEN '❌ Admin CANNOT upload (flag disabled)'
        ELSE '❌ No admin found'
    END as upload_permission
FROM businesses b
CROSS JOIN admin_check ac
WHERE b.allow_admin_deal_creation = true
LIMIT 5;

-- 6.2 Check real-time: Can members read the URL?
-- This simulates member trying to SELECT discounts
SELECT 
    COUNT(*) as total_discounts_member_can_see,
    COUNT(CASE WHEN image_url IS NOT NULL THEN 1 END) as with_images,
    COUNT(CASE WHEN image_url IS NULL THEN 1 END) as without_images,
    '✅ Member can read all' as member_access
FROM trusted_partner_discounts
WHERE is_active = true;

-- ============================================================================
-- 7. TROUBLESHOOTING QUERIES
-- ============================================================================

-- 7.1 Find discounts with images that failed to display
SELECT 
    id,
    name,
    image_url,
    CASE 
        WHEN image_url IS NULL THEN '❌ NULL URL'
        WHEN image_url NOT LIKE 'https://%' THEN '❌ Invalid URL format'
        WHEN image_url NOT LIKE '%business-bills%' THEN '❌ Wrong bucket'
        WHEN image_url NOT LIKE '%deal_images%' THEN '❌ Wrong path'
        ELSE '✅ URL looks valid'
    END as url_status
FROM trusted_partner_discounts
WHERE image_url IS NOT NULL OR image_url IS NULL
LIMIT 20;

-- 7.2 Check if any RLS policies are RESTRICTIVE instead of PERMISSIVE
SELECT 
    policyname,
    permissive,
    CASE 
        WHEN permissive = false THEN '⚠️ RESTRICTIVE policy (might block)'
        WHEN permissive = true THEN '✅ PERMISSIVE policy'
    END as policy_type,
    cmd
FROM pg_policies
WHERE (schemaname = 'public' AND tablename = 'trusted_partner_discounts')
   OR (schemaname = 'storage' AND tablename = 'objects' 
       AND policyname LIKE '%deal image%')
ORDER BY schemaname, tablename, permissive;

-- 7.3 Verify path parsing works correctly
-- This tests if split_part() correctly extracts partner ID from path
SELECT 
    'deal_images/550e8400-e29b-41d4-a716-446655440000/1234567890_test.jpg' as example_path,
    split_part('deal_images/550e8400-e29b-41d4-a716-446655440000/1234567890_test.jpg', '/', 2) as extracted_partner_id,
    CASE 
        WHEN split_part('deal_images/550e8400-e29b-41d4-a716-446655440000/1234567890_test.jpg', '/', 2) 
             = '550e8400-e29b-41d4-a716-446655440000'
        THEN '✅ Path parsing works'
        ELSE '❌ Path parsing broken'
    END as status;

-- ============================================================================
-- EXPECTED RESULTS SUMMARY
-- ============================================================================

/*
✅ All of these should return results:

1. ✅ image_url column exists in trusted_partner_discounts
2. ✅ At least one discount has a valid image_url
3. ✅ At least one business has allow_admin_deal_creation=true
4. ✅ At least one admin exists in memberships
5. ✅ Members can view all discounts RLS policy exists
6. ✅ business-bills bucket exists and is public
7. ✅ Deal image files exist in storage (if any were uploaded)
8. ✅ Members can view deal images policy exists
9. ✅ Admins can manage deal images policy exists
10. ✅ Members can read ALL discount records in table
11. ✅ Path parsing splits correctly

If any are missing, review the corresponding section in ADMIN_DEAL_IMAGE_VERIFICATION.md
*/
```

---

## Quick Status Check

Copy and run this single query to get a quick overview:

```sql
-- QUICK STATUS CHECK (Run this first)
WITH admin_count AS (
    SELECT COUNT(*) as count FROM memberships WHERE role = 'admin'
),
business_count AS (
    SELECT COUNT(*) as count FROM businesses WHERE allow_admin_deal_creation = true
),
discount_with_images AS (
    SELECT COUNT(*) as count FROM trusted_partner_discounts WHERE image_url IS NOT NULL
),
storage_files AS (
    SELECT COUNT(*) as count FROM storage.objects 
    WHERE bucket_id = 'business-bills' AND name LIKE 'deal_images/%'
),
policies AS (
    SELECT COUNT(*) as count FROM pg_policies 
    WHERE (schemaname = 'public' AND tablename = 'trusted_partner_discounts')
       OR (schemaname = 'storage' AND tablename = 'objects' AND policyname LIKE '%deal image%')
)
SELECT 
    'Admins in system' as check_item,
    (SELECT count FROM admin_count) as count,
    CASE WHEN (SELECT count FROM admin_count) > 0 THEN '✅' ELSE '❌' END as status
UNION ALL
SELECT 
    'Businesses allowing admin' as check_item,
    (SELECT count FROM business_count) as count,
    CASE WHEN (SELECT count FROM business_count) > 0 THEN '✅' ELSE '❌' END as status
UNION ALL
SELECT 
    'Discounts with images' as check_item,
    (SELECT count FROM discount_with_images) as count,
    CASE WHEN (SELECT count FROM discount_with_images) > 0 THEN '✅' ELSE '⚠️ (none yet)' END as status
UNION ALL
SELECT 
    'Image files in storage' as check_item,
    (SELECT count FROM storage_files) as count,
    CASE WHEN (SELECT count FROM storage_files) > 0 THEN '✅' ELSE '⚠️ (none yet)' END as status
UNION ALL
SELECT 
    'RLS policies configured' as check_item,
    (SELECT count FROM policies) as count,
    CASE WHEN (SELECT count FROM policies) >= 4 THEN '✅' ELSE '❌' END as status;
```

This gives you a dashboard view of all the critical pieces!
