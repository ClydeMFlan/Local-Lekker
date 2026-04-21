-- =============================================================================
-- CLEAN UP RLS POLICIES - Remove conflicting/overlapping policies
-- =============================================================================
-- The current setup has too many overlapping policies causing conflicts
-- This script removes redundant policies and keeps only the essential ones
-- =============================================================================

-- =============================================================================
-- 1. BUSINESSES TABLE - Clean up overlapping policies
-- =============================================================================
-- Keep only essential policies, remove conflicts
DROP POLICY IF EXISTS "Trusted partners can manage their businesses" ON businesses;
DROP POLICY IF EXISTS "Trusted partners can view own business" ON businesses;
DROP POLICY IF EXISTS "Trusted partners can update own business" ON businesses;
DROP POLICY IF EXISTS "Service role can manage businesses" ON businesses;

-- Keep these core policies:
-- "Members can view businesses" (SELECT)
-- "Business owners can update their business" (UPDATE)
-- "Authenticated members can create businesses" (INSERT)

-- =============================================================================
-- 2. TRUSTED_PARTNER_DISCOUNTS TABLE - Major cleanup needed (11 policies!)
-- =============================================================================
-- This table has WAY too many policies causing conflicts
-- STEP 2 already created the proper unified policies, so just remove conflicts
DROP POLICY IF EXISTS "Service role can manage trusted_partner discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Trusted partners can manage their discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Admin full access to trusted_partner_discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can delete their own discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can insert their own discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can view their own discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Users can view active discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can view active discounts from all trusted partners" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Members can update their own discounts" ON trusted_partner_discounts;
DROP POLICY IF EXISTS "Anyone can view discounts" ON trusted_partner_discounts; -- Remove duplicate
DROP POLICY IF EXISTS "Users can view all discounts" ON trusted_partner_discounts; -- Remove duplicate

-- STEP 2 already created the correct policies:
-- "Members can view all discounts" (SELECT) - allows everyone to view
-- "Business owners can manage their discounts" (ALL) - business owners can manage

-- =============================================================================
-- 3. PROCESSED_BILLS TABLE - Simplify policies
-- =============================================================================
-- Current policies look reasonable, but ensure they're not conflicting
-- Keep: Members can view/insert/update their own processed bills

-- =============================================================================
-- 4. DEAL_AUTHORIZATIONS TABLE - Policies look good
-- =============================================================================
-- Current policies are appropriate:
-- Members can insert/view their authorizations
-- Trusted partners can view/update authorizations for their business

-- =============================================================================
-- 5. NOTIFICATIONS TABLE - Policies look good
-- =============================================================================
-- Current policies are appropriate:
-- Members can view their notifications
-- Authenticated members can insert notifications

-- =============================================================================
-- FINAL CLEANUP - Remove remaining duplicate policies
-- =============================================================================

-- Remove duplicate SELECT policies on businesses
DROP POLICY IF EXISTS "Members can view businesses" ON businesses; -- Keep "Members can view all businesses"

-- Remove duplicate SELECT policies on deal_authorizations
-- Keep "Members can view their authorizations", remove any duplicates

-- Remove duplicate SELECT policies on processed_bills
-- Keep "Members can view their own bills", remove any duplicates

-- Final verification
SELECT
    schemaname,
    tablename,
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE tablename IN ('businesses', 'processed_bills', 'deal_authorizations', 'notifications', 'trusted_partner_discounts')
ORDER BY tablename, cmd, policyname;