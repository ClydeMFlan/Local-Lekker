-- Check That Old Oak logo mismatch

-- 1. What's in the database for That Old Oak
SELECT 
    b.name,
    b.owner_member_id,
    b.logo_url,
    b.updated_at as db_updated_at,
    -- Extract filename from URL
    SUBSTRING(b.logo_url FROM 'logo_\d+\.(jpg|png)') as db_filename
FROM businesses b
WHERE b.owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';

-- 2. What's in storage for That Old Oak
SELECT 
    name as storage_filename,
    owner,
    created_at as storage_created_at,
    updated_at as storage_updated_at
FROM storage.objects
WHERE bucket_id = 'partner-logos'
  AND owner = '1916d77f-596f-4e9f-825f-dedf7a11bbf8'
ORDER BY created_at DESC;

-- 3. Compare database filename vs latest storage file
SELECT 
    'Database has' as source,
    SUBSTRING(b.logo_url FROM 'logo_\d+\.(jpg|png)') as filename,
    b.updated_at as timestamp
FROM businesses b
WHERE b.owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8'

UNION ALL

SELECT 
    'Storage has' as source,
    name as filename,
    created_at as timestamp
FROM storage.objects
WHERE bucket_id = 'partner-logos'
  AND owner = '1916d77f-596f-4e9f-825f-dedf7a11bbf8'
ORDER BY timestamp DESC;

-- 4. Check if the database URL points to a file that actually exists
SELECT 
    b.name,
    b.logo_url as database_url,
    SUBSTRING(b.logo_url FROM 'logo_\d+\.(jpg|png)$') as filename_from_url,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM storage.objects 
            WHERE bucket_id = 'partner-logos' 
              AND (
                  -- Match either full path or filename depending on storage implementation
                  name = '1916d77f-596f-4e9f-825f-dedf7a11bbf8/' || SUBSTRING(b.logo_url FROM 'logo_\d+\.(jpg|png)$')
                  OR name LIKE '%' || SUBSTRING(b.logo_url FROM 'logo_\d+\.(jpg|png)$')
              )
        ) THEN '✅ File EXISTS in storage'
        ELSE '❌ File NOT FOUND in storage'
    END as file_status
FROM businesses b
WHERE b.owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';
