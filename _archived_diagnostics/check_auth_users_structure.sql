
-- Check the actual structure of auth.users table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'auth' 
AND table_name = 'users'
ORDER BY ordinal_position;

-- Check what a real user record looks like
SELECT *
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 1;

