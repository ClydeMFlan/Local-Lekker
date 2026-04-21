-- Comprehensive query to check clydemfaln member profile and identify missing fields
-- Run this in your Supabase SQL Editor to see the current state

-- 1. Check profiles table for clydemfaln
SELECT
    'PROFILES TABLE' as table_name,
    id,
    email,
    name,
    surname,
    date_of_birth,
    gender,
    ethnicity,
    province,
    street,
    suburb,
    city,
    contact,
    role,
    subscription,
    created_at,
    updated_at
FROM public.profiles
WHERE email ILIKE '%clydemfaln%' OR name ILIKE '%clydemfaln%' OR surname ILIKE '%clydemfaln%';

-- 2. Check auth.users table for clydemfaln
SELECT
    'AUTH.USERS TABLE' as table_name,
    id,
    email,
    email_confirmed_at,
    created_at,
    last_sign_in_at,
    raw_user_meta_data,
    raw_app_meta_data
FROM auth.users
WHERE email ILIKE '%clydemfaln%';

-- 3. Check memberships table
SELECT
    'MEMBERSHIPS TABLE' as table_name,
    m.user_id,
    m.role,
    m.gateway,
    m.created_at,
    p.email,
    p.name,
    p.surname
FROM public.memberships m
LEFT JOIN public.profiles p ON m.user_id = p.id
WHERE p.email ILIKE '%clydemfaln%' OR p.name ILIKE '%clydemfaln%' OR p.surname ILIKE '%clydemfaln%';

-- 4. Detailed null field analysis for clydemfaln profile
SELECT
    'NULL FIELD ANALYSIS' as analysis_type,
    id,
    email,
    CASE WHEN name IS NULL OR name = '' THEN 'MISSING' ELSE 'PRESENT' END as name_status,
    CASE WHEN surname IS NULL OR surname = '' THEN 'MISSING' ELSE 'PRESENT' END as surname_status,
    CASE WHEN date_of_birth IS NULL THEN 'MISSING' ELSE 'PRESENT' END as dob_status,
    CASE WHEN gender IS NULL OR gender = '' THEN 'MISSING' ELSE 'PRESENT' END as gender_status,
    CASE WHEN ethnicity IS NULL OR ethnicity = '' THEN 'MISSING' ELSE 'PRESENT' END as ethnicity_status,
    CASE WHEN province IS NULL OR province = '' THEN 'MISSING' ELSE 'PRESENT' END as province_status,
    CASE WHEN street IS NULL OR street = '' THEN 'MISSING' ELSE 'PRESENT' END as street_status,
    CASE WHEN suburb IS NULL OR suburb = '' THEN 'MISSING' ELSE 'PRESENT' END as suburb_status,
    CASE WHEN city IS NULL OR city = '' THEN 'MISSING' ELSE 'PRESENT' END as city_status,
    CASE WHEN contact IS NULL OR contact = '' THEN 'MISSING' ELSE 'PRESENT' END as contact_status,
    role,
    subscription
FROM public.profiles
WHERE email ILIKE '%clydemfaln%' OR name ILIKE '%clydemfaln%' OR surname ILIKE '%clydemfaln%';