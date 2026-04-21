-- Quick diagnostic query for clydemfaln sign-in issue
-- Copy and paste this into your Supabase SQL Editor

-- Check if clydemfaln exists in profiles
SELECT 'PROFILES' as source, COUNT(*) as count
FROM public.profiles
WHERE email ILIKE '%clydemfaln%';

-- Check if clydemfaln exists in auth.users
SELECT 'AUTH_USERS' as source, COUNT(*) as count
FROM auth.users
WHERE email ILIKE '%clydemfaln%';

-- Get detailed info about clydemfaln
SELECT
    p.id,
    p.email as profile_email,
    u.email as auth_email,
    u.email_confirmed_at,
    p.role,
    p.subscription,
    p.name,
    p.surname,
    p.contact,
    CASE WHEN u.email_confirmed_at IS NULL THEN 'EMAIL_NOT_CONFIRMED' ELSE 'EMAIL_CONFIRMED' END as email_status,
    CASE WHEN p.name IS NULL OR p.name = '' THEN 'MISSING_NAME' ELSE 'HAS_NAME' END as name_status,
    CASE WHEN p.contact IS NULL OR p.contact = '' THEN 'MISSING_CONTACT' ELSE 'HAS_CONTACT' END as contact_status
FROM public.profiles p
FULL OUTER JOIN auth.users u ON p.id = u.id
WHERE p.email ILIKE '%clydemfaln%' OR u.email ILIKE '%clydemfaln%';