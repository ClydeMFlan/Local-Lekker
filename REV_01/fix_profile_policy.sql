-- Fix for profile creation issue after OTP verification
-- Run this SQL in your Supabase SQL Editor to add the missing INSERT policy

-- Add INSERT policy for profiles table to allow authenticated users to create their own profiles
CREATE POLICY "Users can insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Verify the policy was created
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'profiles';