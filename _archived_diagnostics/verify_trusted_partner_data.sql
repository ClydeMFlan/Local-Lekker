-- Verify Trusted Partner Data Exists
-- This checks all the data for the trusted partner to ensure everything is in place

-- 1. Check memberships for trusted partners
SELECT 
    user_id, 
    role, 
    gateway, 
    created_at
FROM public.memberships
WHERE role = 'trusted_partner'
ORDER BY created_at DESC;

-- 2. Check if profiles exist for these trusted partners
SELECT 
    p.id,
    p.name,
    p.surname,
    p.email,
    p.role,
    p.created_at
FROM public.profiles p
WHERE p.id IN (
    SELECT user_id 
    FROM public.memberships 
    WHERE role = 'trusted_partner'
);

-- 3. Check trusted_partners table entries
SELECT 
    tp.user_id,
    tp.business_name,
    tp.created_at,
    p.name,
    p.surname,
    p.email
FROM public.trusted_partners tp
LEFT JOIN public.profiles p ON tp.user_id = p.id
WHERE tp.user_id IN (
    SELECT user_id 
    FROM public.memberships 
    WHERE role = 'trusted_partner'
);

-- 4. Full joined view - exactly what the app should see
SELECT 
    m.user_id,
    m.role AS membership_role,
    m.gateway,
    p.name,
    p.surname,
    p.email,
    p.role AS profile_role,
    tp.business_name,
    p.created_at
FROM public.memberships m
LEFT JOIN public.profiles p ON m.user_id = p.id
LEFT JOIN public.trusted_partners tp ON m.user_id = tp.user_id
WHERE m.role = 'trusted_partner'
ORDER BY p.created_at DESC;
