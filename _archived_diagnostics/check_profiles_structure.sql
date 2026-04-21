-- Check the actual profiles table structure and clydemfaln data
-- Run this in Supabase SQL Editor

-- 1. Check table structure
SELECT
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public'
AND table_name = 'profiles'
ORDER BY ordinal_position;

-- 2. Check clydemfaln profile data
SELECT * FROM public.profiles
WHERE email ILIKE '%clydemfaln%' OR name ILIKE '%clydemfaln%' OR surname ILIKE '%clydemfaln%';

-- 3. Check if clydemfaln exists in auth.users
SELECT
    id,
    email,
    email_confirmed_at,
    created_at
FROM auth.users
WHERE email ILIKE '%clydemfaln%';

-- 4. Check memberships for clydemfaln
SELECT
    m.user_id,
    m.role,
    m.gateway,
    p.email,
    p.name,
    p.surname,
    p.category,
    p.in_app_password,
    p.subscription
FROM public.memberships m
LEFT JOIN public.profiles p ON m.user_id = p.id
WHERE p.email ILIKE '%clydemfaln%' OR p.name ILIKE '%clydemfaln%' OR p.surname ILIKE '%clydemfaln%';