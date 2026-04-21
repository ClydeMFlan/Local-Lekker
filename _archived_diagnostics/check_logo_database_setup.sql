-- Check database structure and RLS policies for logo images

-- 1. Check businesses table structure and logo_url column
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'businesses'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2. Check current logo URLs in businesses table
SELECT 
    b.id,
    b.name,
    b.owner_member_id,
    b.logo_url,
    b.updated_at,
    tp.business_name
FROM businesses b
LEFT JOIN trusted_partners tp ON b.owner_member_id = tp.user_id
ORDER BY b.updated_at DESC
LIMIT 10;

-- 3. Check storage.objects for partner-logos bucket
SELECT 
    name,
    bucket_id,
    owner,
    created_at,
    updated_at,
    metadata
FROM storage.objects
WHERE bucket_id = 'partner-logos'
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check RLS policies on storage.objects for partner-logos
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'objects'
    AND schemaname = 'storage'
    AND policyname LIKE '%partner-logo%'
ORDER BY policyname;

-- 5. Check storage buckets configuration
SELECT 
    id,
    name,
    public,
    avif_autodetection,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE name IN ('partner-logos', 'business-logos')
ORDER BY name;

-- 6. Verify That Old Oak specifically
SELECT 
    b.id,
    b.name,
    b.owner_member_id,
    b.logo_url,
    b.updated_at,
    (SELECT name FROM storage.objects 
     WHERE bucket_id = 'partner-logos' 
     AND owner::uuid = b.owner_member_id 
     ORDER BY created_at DESC LIMIT 1) as latest_storage_file
FROM businesses b
WHERE b.owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';

-- 7. Check if there are any logo_url entries pointing to wrong bucket
SELECT 
    id,
    name,
    owner_member_id,
    logo_url,
    CASE 
        WHEN logo_url LIKE '%partner-logos%' THEN 'partner-logos'
        WHEN logo_url LIKE '%business-logos%' THEN 'business-logos (WRONG)'
        WHEN logo_url LIKE '%business-bills%' THEN 'business-bills (WRONG)'
        ELSE 'Unknown bucket or NULL'
    END as bucket_used
FROM businesses
WHERE logo_url IS NOT NULL
ORDER BY updated_at DESC;
