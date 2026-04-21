-- Verify RLS Policies for partner-logos Storage Bucket

-- 1. Check all RLS policies on storage.objects
SELECT 
    policyname,
    cmd,
    roles,
    qual::text as "using_expression",
    with_check::text as "with_check_expression"
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
ORDER BY policyname;

-- 2. Specifically check partner-logos policies
SELECT 
    policyname,
    cmd,
    roles,
    qual::text as "using_expression"
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND qual::text LIKE '%partner-logo%'
ORDER BY policyname;

-- 3. Check if partner-logos bucket is public
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE name = 'partner-logos';

-- 4. Test admin can write (requires admin role context)
-- This shows what the policy checks
SELECT 
    name,
    bucket_id,
    owner
FROM storage.objects
WHERE bucket_id = 'partner-logos'
  AND owner IN (
    SELECT id::text 
    FROM profiles 
    WHERE role = 'admin'
  )
ORDER BY created_at DESC
LIMIT 5;

-- 5. Verify businesses table has correct logo_url format
SELECT 
    b.owner_member_id,
    b.name,
    b.logo_url,
    CASE 
        WHEN b.logo_url IS NULL THEN 'No logo'
        WHEN b.logo_url LIKE '%partner-logos%' THEN '✅ Correct bucket'
        WHEN b.logo_url LIKE '%business-logos%' THEN '❌ Wrong bucket (business-logos)'
        WHEN b.logo_url LIKE '%business_logos%' THEN '❌ Wrong bucket (business_logos)'
        ELSE '⚠️ Unknown format'
    END as bucket_check,
    CASE 
        WHEN b.logo_url IS NULL THEN 'N/A'
        WHEN b.logo_url LIKE '%logo_%' THEN '✅ Has timestamp'
        ELSE '⚠️ No timestamp in filename'
    END as filename_check
FROM businesses b
WHERE b.logo_url IS NOT NULL
ORDER BY b.updated_at DESC;

-- 6. Cross-reference: businesses with logos but missing storage files
SELECT 
    b.owner_member_id,
    b.name as business_name,
    b.logo_url,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM storage.objects 
            WHERE bucket_id = 'partner-logos' 
              AND owner = b.owner_member_id::text
              AND b.logo_url LIKE '%' || name || '%'
        ) THEN '✅ File exists in storage'
        ELSE '❌ File NOT found in storage'
    END as storage_status
FROM businesses b
WHERE b.logo_url IS NOT NULL
  AND b.logo_url LIKE '%partner-logos%'
ORDER BY b.updated_at DESC;

-- 7. Check for orphaned storage files (in storage but not in database)
SELECT 
    o.name as filename,
    o.owner,
    o.created_at,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM businesses 
            WHERE owner_member_id::text = o.owner
              AND logo_url LIKE '%' || o.name || '%'
        ) THEN '✅ Referenced in database'
        ELSE '⚠️ Orphaned (not in database)'
    END as database_status
FROM storage.objects o
WHERE o.bucket_id = 'partner-logos'
ORDER BY o.created_at DESC
LIMIT 20;

-- 8. Summary: Logo status by trusted partner
SELECT 
    tp.owner_member_id,
    tp.business_name,
    tp.verified_status,
    b.logo_url IS NOT NULL as has_logo_url,
    CASE 
        WHEN b.logo_url IS NULL THEN 'No logo set'
        WHEN EXISTS (
            SELECT 1 FROM storage.objects 
            WHERE bucket_id = 'partner-logos' 
              AND owner = tp.owner_member_id::text
              AND b.logo_url LIKE '%' || name || '%'
        ) THEN '✅ Complete (DB + Storage)'
        ELSE '⚠️ URL set but file missing'
    END as logo_status
FROM trusted_partners tp
LEFT JOIN businesses b ON b.owner_member_id = tp.owner_member_id
WHERE tp.verified_status = 'verified'
ORDER BY tp.business_name;
