-- Check RLS policies on businesses table for UPDATE operations
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
WHERE tablename = 'businesses' 
  AND schemaname = 'public'
  AND cmd = 'UPDATE'
ORDER BY policyname;
