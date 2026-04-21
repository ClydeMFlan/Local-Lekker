-- Debug script to check subscriptions table and RLS policies
-- Run this in Supabase SQL Editor

-- 1. Check if subscriptions table exists
SELECT 
    schemaname, 
    tablename, 
    tableowner 
FROM pg_tables 
WHERE tablename = 'subscriptions';

-- 2. Check table structure
SELECT 
    column_name, 
    data_type, 
    is_nullable 
FROM information_schema.columns 
WHERE table_name = 'subscriptions' 
ORDER BY ordinal_position;

-- 3. Check RLS is enabled
SELECT 
    schemaname, 
    tablename, 
    rowsecurity 
FROM pg_tables 
WHERE tablename = 'subscriptions';

-- 4. Check existing RLS policies
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'subscriptions';

-- 5. Check if user has any subscriptions (as authenticated user)
-- This will show you the actual data
SELECT 
    id,
    user_id,
    plan_type,
    status,
    created_at,
    updated_at
FROM subscriptions
WHERE user_id = '80eff2dc-6297-4d50-a22b-6213213f659f'
ORDER BY created_at DESC;

-- 6. Count total subscriptions in table (run as service_role if available)
SELECT COUNT(*) as total_subscriptions FROM subscriptions;

-- 7. Check if the specific user ID exists in auth.users
SELECT 
    id, 
    email, 
    created_at 
FROM auth.users 
WHERE id = '80eff2dc-6297-4d50-a22b-6213213f659f';
