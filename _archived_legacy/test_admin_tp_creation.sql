
-- Test script to verify admin trusted partner creation
-- Run this in Supabase SQL Editor after applying the fixes

-- 1. Check current trigger function
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'handle_new_user_role_assignment';

-- 2. Check RLS policies for trusted_partners
SELECT schemaname, tablename, policyname, cmd, qual, roles
FROM pg_policies 
WHERE tablename = 'trusted_partners';

-- 3. Check if trigger is installed
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'users' AND event_object_schema = 'auth';

-- 4. Test query - Check recent trusted partner creations
SELECT 
    tp.user_id,
    tp.business_name,
    p.email,
    p.name,
    p.surname,
    p.role,
    p.admin_created,
    p.password_set,
    m.role as membership_role,
    tp.created_at
FROM trusted_partners tp
JOIN profiles p ON tp.user_id = p.id
JOIN memberships m ON tp.user_id = m.user_id
WHERE tp.created_at > NOW() - INTERVAL '1 hour'
ORDER BY tp.created_at DESC;

-- 5. Check for any RLS policy violations in logs (if available)
-- This would show up in Supabase dashboard logs if there are permission issues

