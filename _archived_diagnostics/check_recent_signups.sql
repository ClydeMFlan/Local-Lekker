-- Check current users in profiles table
SELECT 
    id,
    name,
    surname,
    email,
    role,
    subscription,
    created_at
FROM 
    public.profiles 
ORDER BY 
    created_at DESC 
LIMIT 10;

-- Check current users in memberships table
SELECT 
    user_id,
    role,
    gateway,
    created_at
FROM 
    public.memberships 
ORDER BY 
    created_at DESC 
LIMIT 10;

-- Check if there are any recent auth users
SELECT 
    id,
    email,
    created_at,
    last_sign_in_at
FROM 
    auth.users 
ORDER BY 
    created_at DESC 
LIMIT 10;
