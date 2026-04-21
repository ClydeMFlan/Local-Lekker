-- Fix deal_authorizations UPDATE policies to allow members to update payment_completed_at

-- 1. First, let's see the current policies
SELECT 
  policyname,
  permissive,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'deal_authorizations'
AND cmd = 'UPDATE';

-- 2. DROP the restrictive policies
DROP POLICY IF EXISTS "deal_auth_update_business" ON public.deal_authorizations;
DROP POLICY IF EXISTS "deal_auth_update_member" ON public.deal_authorizations;

-- 3. CREATE a single comprehensive UPDATE policy that allows:
--    - Members to update their own deals (to set payment_completed_at)
--    - Trusted partners to update deals they're assigned to (to set approved_at, completed_at, etc.)
CREATE POLICY "Members and trusted partners can update deal authorizations" 
ON public.deal_authorizations
FOR UPDATE 
USING (
  -- Allow if user is the member on this deal
  auth.uid() = member_id
  OR
  -- Allow if user is the trusted partner on this deal
  auth.uid() = trusted_partner_id
)
WITH CHECK (
  -- Allow if user is the member on this deal
  auth.uid() = member_id
  OR
  -- Allow if user is the trusted partner on this deal
  auth.uid() = trusted_partner_id
);

-- 4. Verify the new policy
SELECT 
  policyname,
  permissive,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'deal_authorizations'
AND cmd = 'UPDATE';
