-- Check if user is authenticated and confirmed
-- Note: This checks basic user existence and confirmation status
-- For full authentication status, use Supabase client methods

-- Check if user exists and is confirmed
SELECT
    id,
    email,
    email_confirmed_at,
    created_at,
    last_sign_in_at,
    CASE
        WHEN email_confirmed_at IS NOT NULL THEN 'Confirmed'
        ELSE 'Not Confirmed'
    END as confirmation_status
FROM auth.users
WHERE email = 'clydemflan@gmail.com';

-- Alternative: Check if user exists (without showing sensitive details)
SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM auth.users
            WHERE email = 'clydemflan@gmail.com'
            AND email_confirmed_at IS NOT NULL
        ) THEN 'User exists and is confirmed'
        ELSE 'User does not exist or is not confirmed'
    END as authentication_status;