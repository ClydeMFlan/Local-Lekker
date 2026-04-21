-- Check deal image storage setup

-- 1. What storage buckets exist for images?
SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    CASE 
        WHEN name = 'deal-images' THEN '✅ Correct bucket for deal images'
        WHEN name = 'business-bills' THEN '⚠️ Currently used for deal images (wrong)'
        ELSE 'Other bucket'
    END as bucket_purpose
FROM storage.buckets
WHERE name IN ('deal-images', 'business-bills', 'deal_images')
ORDER BY name;

-- 2. Check current deal image files in storage
SELECT 
    name as file_path,
    bucket_id,
    owner,
    created_at,
    CASE 
        WHEN name LIKE 'deal_images/%' THEN '📁 Deal image file'
        ELSE 'Other file'
    END as file_type
FROM storage.objects
WHERE bucket_id IN ('business-bills', 'deal-images', 'deal_images')
  AND name LIKE '%deal%'
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check trusted_partner_discounts table structure for image_url column
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'trusted_partner_discounts'
  AND column_name LIKE '%image%'
ORDER BY ordinal_position;

-- 4. Check current deal image URLs in database
SELECT 
    id,
    name,
    image_url,
    trusted_partner_id,
    CASE 
        WHEN image_url LIKE '%business-bills%' THEN '⚠️ Using business-bills bucket'
        WHEN image_url LIKE '%deal-images%' THEN '✅ Using deal-images bucket'
        WHEN image_url LIKE '%deal_images%' THEN '✅ Using deal_images bucket'
        WHEN image_url IS NULL THEN 'No image'
        ELSE 'Unknown bucket'
    END as bucket_check
FROM trusted_partner_discounts
WHERE image_url IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- 5. Check RLS policies on storage.objects for deal images
SELECT 
    policyname,
    cmd,
    qual::text as using_expression
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    qual::text LIKE '%deal%'
    OR policyname LIKE '%deal%'
  )
ORDER BY policyname;
