-- Check if profile exists for clydemflan@gmail.com
SELECT id, email, role, subscription, created_at
FROM public.profiles
WHERE email = 'clydemflan@gmail.com';

-- Also check the auth.users table
SELECT id, email, created_at
FROM auth.users
WHERE email = 'clydemflan@gmail.com';