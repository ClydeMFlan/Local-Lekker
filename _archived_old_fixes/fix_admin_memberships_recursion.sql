-- =====================================================
-- FIX: Infinite Recursion in Memberships Policies
-- =====================================================
-- Problem: Admin policies check memberships table while inserting into it
-- This causes infinite recursion when admin creates trusted partners
-- Solution: Use profiles table instead of memberships table

-- Drop the problematic policies
DROP POLICY IF EXISTS "Admins can view all memberships" ON public.memberships;
DROP POLICY IF EXISTS "Admins can insert any membership" ON public.memberships;
DROP POLICY IF EXISTS "Admins can update any membership" ON public.memberships;
DROP POLICY IF EXISTS "Admins can delete any membership" ON public.memberships;
DROP POLICY IF EXISTS "Admin can view all memberships" ON public.memberships;

-- Recreate policies using profiles table to avoid recursion
CREATE POLICY "Admins can view all memberships" ON public.memberships
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can insert any membership" ON public.memberships
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can update any membership" ON public.memberships
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

CREATE POLICY "Admins can delete any membership" ON public.memberships
    FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );

-- Verify policies
SELECT tablename, policyname, cmd,
       CASE
           WHEN qual LIKE '%profiles%' THEN 'Uses profiles (GOOD)'
           WHEN qual LIKE '%memberships%' THEN 'Uses memberships (CAUSES RECURSION)'
           ELSE 'Other'
       END as policy_check
FROM pg_policies
WHERE tablename = 'memberships' AND policyname LIKE '%Admin%'
ORDER BY policyname;
