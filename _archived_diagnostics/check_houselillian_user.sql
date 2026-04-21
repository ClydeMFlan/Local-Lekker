-- Check if houselillian5@gmail.com exists in auth.users and get their user ID
SELECT
    'User exists in auth.users' as status,
    id as user_id,
    email,
    created_at,
    last_sign_in_at
FROM auth.users
WHERE email = 'houselillian5@gmail.com';

-- If user doesn't exist, we'll need to create them first
-- For now, let's assume they exist and get their current profile state