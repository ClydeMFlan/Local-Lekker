-- Fix Admin Access to View Trusted Partners
-- This script ensures admins can view memberships and profiles for all users

-- First, let's check current policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE tablename IN ('memberships', 'profiles')
ORDER BY tablename, policyname;

-- Drop existing restrictive policies on memberships if they exist
DROP POLICY IF EXISTS "Users can view their own membership" ON public.memberships;
DROP POLICY IF EXISTS "Users can insert their own membership" ON public.memberships;

-- Create new policies for memberships table
-- Allow users to view their own membership
CREATE POLICY "Users can view their own membership" ON public.memberships
    FOR SELECT
    USING (auth.uid() = user_id);

-- Allow admins to view all memberships
CREATE POLICY "Admins can view all memberships" ON public.memberships
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow authenticated users to insert their own membership
CREATE POLICY "Users can insert their own membership" ON public.memberships
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Allow admins to insert memberships for any user
CREATE POLICY "Admins can insert any membership" ON public.memberships
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow admins to update any membership
CREATE POLICY "Admins can update any membership" ON public.memberships
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Allow admins to delete any membership
CREATE POLICY "Admins can delete any membership" ON public.memberships
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.memberships
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );

-- Verify the policies were created
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'memberships'
ORDER BY policyname;

-- Test query: Check if admin can see trusted partner memberships
-- Run this as your admin user to verify
SELECT user_id, role, gateway, created_at
FROM public.memberships
WHERE role = 'trusted_partner'
ORDER BY created_at DESC;
