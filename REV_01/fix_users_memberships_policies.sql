-- Fix for users table INSERT policy
-- Run this SQL in your Supabase SQL Editor to add the missing INSERT policy

-- Add INSERT policy for users table to allow authenticated users to create their own user records
CREATE POLICY "Users can insert own user record" ON public.users
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Add INSERT policy for memberships table to allow authenticated users to create memberships
CREATE POLICY "Users can insert memberships" ON public.memberships
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('users', 'memberships')
ORDER BY tablename, policyname;