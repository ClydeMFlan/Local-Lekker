-- Verify storage object exists for partner logo path
-- Replace values accordingly when testing other partners
SELECT
  so.id,
  so.bucket_id,
  so.name,
  so.owner,
  so.created_at
FROM storage.objects so
WHERE so.bucket_id = 'partner-logos'
  AND so.name LIKE '1916d77f-596f-4e9f-825f-dedf7a11bbf8/%'
ORDER BY so.created_at DESC;
