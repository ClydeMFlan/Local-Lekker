-- Check existing RLS policies on storage.objects for partner-logos bucket
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
  AND (policyname LIKE '%partner%logo%' OR policyname LIKE '%logo%')
ORDER BY policyname;

-- Check if partner-logos bucket exists and is public
SELECT 
    id,
    name,
    public,
    avif_autodetection,
    file_size_limit,
    allowed_mime_types
FROM storage.buckets
WHERE id = 'partner-logos';
