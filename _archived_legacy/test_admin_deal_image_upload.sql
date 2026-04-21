-- Test script to verify admin deal image upload permissions
-- Run this AFTER applying fix_admin_deal_image_upload_rls.sql

-- Step 1: Verify current user is an admin
SELECT 
    'Step 1: Check current user role' as test_step,
    user_id,
    role,
    CASE 
        WHEN role = 'admin' THEN '✓ User is admin'
        ELSE '✗ User is NOT admin - this is the problem!'
    END as result
FROM public.memberships
WHERE user_id = auth.uid();

-- Step 2: List all businesses that allow admin deal creation
SELECT
    'Step 2: Businesses allowing admin deal creation' as test_step,
    b.id as business_id,
    b.name as business_name,
    b.owner_member_id as partner_user_id,
    p.name || ' ' || COALESCE(p.surname, '') as partner_name,
    b.allow_admin_deal_creation,
    CASE
        WHEN b.allow_admin_deal_creation = true THEN '✓ Admin can create deals'
        ELSE '✗ Admin CANNOT create deals'
    END as permission_status
FROM public.businesses b
LEFT JOIN public.profiles p ON p.id = b.owner_member_id
WHERE b.allow_admin_deal_creation = true
ORDER BY b.name;

-- Step 3: Check storage policies exist
SELECT 
    'Step 3: Verify storage policies' as test_step,
    schemaname,
    tablename,
    policyname,
    CASE 
        WHEN policyname LIKE '%Admin%' THEN '✓ Admin policy exists'
        WHEN policyname LIKE '%Trusted partner%' THEN '✓ Partner policy exists'
        ELSE '✓ Other policy exists'
    END as policy_type
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%deal image%'
ORDER BY policyname;

-- Step 4: Test path parsing (replace PARTNER_UUID with actual partner UUID)
SELECT 
    'Step 4: Test path parsing' as test_step,
    'deal_images/PARTNER_UUID/test.jpg' as sample_path,
    split_part('deal_images/PARTNER_UUID/test.jpg', '/', 1) as segment_1_should_be_deal_images,
    split_part('deal_images/PARTNER_UUID/test.jpg', '/', 2) as segment_2_should_be_partner_uuid,
    split_part('deal_images/PARTNER_UUID/test.jpg', '/', 3) as segment_3_should_be_filename;

-- Step 5: Simulate the policy check for a specific partner
-- Replace 'PARTNER_UUID_HERE' with the actual partner's user ID you're trying to upload for
SELECT
    'Step 5: Simulate policy check for specific partner' as test_step,
    b.owner_member_id as partner_user_id,
    b.name as business_name,
    b.allow_admin_deal_creation,
    EXISTS (
        SELECT 1 FROM public.memberships m
        WHERE m.user_id = auth.uid() AND m.role = 'admin'
    ) as current_user_is_admin,
    CASE
        WHEN NOT EXISTS (
            SELECT 1 FROM public.memberships m
            WHERE m.user_id = auth.uid() AND m.role = 'admin'
        ) THEN '✗ FAIL: Current user is NOT an admin'
        WHEN b.allow_admin_deal_creation = false OR b.allow_admin_deal_creation IS NULL THEN '✗ FAIL: Partner has NOT allowed admin deal creation'
        WHEN b.allow_admin_deal_creation = true AND EXISTS (
            SELECT 1 FROM public.memberships m
            WHERE m.user_id = auth.uid() AND m.role = 'admin'
        ) THEN '✓ PASS: Upload should work!'
        ELSE '✗ FAIL: Unknown issue'
    END as diagnosis
FROM public.businesses b
WHERE b.owner_member_id = 'PARTNER_UUID_HERE';

-- Step 6: Check if there are any conflicting policies
SELECT 
    'Step 6: Check for conflicting policies' as test_step,
    COUNT(*) as policy_count,
    CASE 
        WHEN COUNT(*) = 9 THEN '✓ Correct number of policies (4 partner + 4 admin + 1 member view)'
        ELSE '⚠ Unexpected number of policies - may have conflicts'
    END as status
FROM pg_policies
WHERE schemaname = 'storage' 
  AND tablename = 'objects'
  AND policyname LIKE '%deal image%';
