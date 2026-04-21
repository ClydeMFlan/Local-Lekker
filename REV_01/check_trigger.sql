-- Check if the trigger is properly attached to auth.users
SELECT
  trigger_name,
  event_manipulation,
  event_object_schema,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'users'
  AND event_object_schema = 'auth';

-- Check the trigger function exists
SELECT
  routine_name,
  routine_type
FROM information_schema.routines
WHERE routine_name = 'handle_new_user_role_assignment'
  AND routine_schema = 'public';

-- Check recent users and their metadata
SELECT
  u.id,
  u.email,
  u.created_at,
  u.raw_app_meta_data->>'user_type' as user_type,
  u.raw_user_meta_data as user_metadata
FROM auth.users u
ORDER BY u.created_at DESC
LIMIT 5;

-- Check if profiles were created for recent users
SELECT
  p.id,
  p.email,
  p.role,
  p.created_at
FROM public.profiles p
ORDER BY p.created_at DESC
LIMIT 5;

-- Check if memberships were created for recent users
SELECT
  m.user_id,
  m.role,
  m.gateway,
  m.created_at
FROM public.memberships m
ORDER BY m.created_at DESC
LIMIT 5;

-- Combined view to see if trigger worked
SELECT
  u.id,
  u.email,
  u.raw_app_meta_data->>'user_type' as signup_type,
  p.role as profile_role,
  m.role as membership_role,
  u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.memberships m ON u.id = m.user_id
ORDER BY u.created_at DESC
LIMIT 10;
