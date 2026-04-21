-- Check RLS policies on businesses table

-- 1. List ALL RLS policies on businesses table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual::text as "using_expression",
    with_check::text as "with_check_expression"
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'businesses'
ORDER BY cmd, policyname;

-- 2. Check if RLS is enabled on businesses table
SELECT 
    schemaname,
    tablename,
    rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'businesses';

-- 3. Check if admin role can UPDATE businesses table
-- This shows what conditions admins must meet to UPDATE
SELECT 
    policyname,
    cmd,
    qual::text as "using_expression",
    with_check::text as "with_check_expression"
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'businesses'
  AND cmd IN ('UPDATE', 'ALL')
  AND (
    qual::text ILIKE '%admin%' 
    OR with_check::text ILIKE '%admin%'
    OR roles::text ILIKE '%admin%'
  )
ORDER BY policyname;

-- 4. Check what policies allow UPDATE on logo_url column specifically
SELECT 
    policyname,
    cmd,
    roles,
    qual::text as "conditions"
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'businesses'
  AND cmd IN ('UPDATE', 'ALL');

-- 5. Test if current admin user can see That Old Oak business row
-- (This simulates the SELECT query in the upload function)
SELECT 
    id,
    name,
    owner_member_id,
    logo_url,
    CASE 
        WHEN id IS NOT NULL THEN '✅ Admin CAN see this row'
        ELSE '❌ Admin CANNOT see this row'
    END as visibility
FROM businesses
WHERE owner_member_id = '1916d77f-596f-4e9f-825f-dedf7a11bbf8';
