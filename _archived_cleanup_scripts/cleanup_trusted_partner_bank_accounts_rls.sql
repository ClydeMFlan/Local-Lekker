-- ========================================
-- CLEANUP AND FIX RLS POLICIES FOR TRUSTED_PARTNER_BANK_ACCOUNTS
-- This script removes old business_id policies and creates clean user_id policies
-- ========================================

-- Step 1: Drop ALL existing policies (both old and new)
DROP POLICY IF EXISTS "Business owners can view their own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Business owners can insert their own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Business owners can update their own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Business owners can delete their own bank accounts" ON trusted_partner_bank_accounts;

DROP POLICY IF EXISTS "Users can view own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Users can insert own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Users can update own bank accounts" ON trusted_partner_bank_accounts;
DROP POLICY IF EXISTS "Users can delete own bank accounts" ON trusted_partner_bank_accounts;

-- Step 2: Ensure RLS is enabled
ALTER TABLE trusted_partner_bank_accounts ENABLE ROW LEVEL SECURITY;

-- Step 3: Create clean user_id based policies

-- Policy: Trusted partners can view their own bank accounts
CREATE POLICY "Users can view own bank accounts"
ON trusted_partner_bank_accounts
FOR SELECT
USING (auth.uid() = user_id);

-- Policy: Trusted partners can insert their own bank accounts
CREATE POLICY "Users can insert own bank accounts"
ON trusted_partner_bank_accounts
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Trusted partners can update their own bank accounts
CREATE POLICY "Users can update own bank accounts"
ON trusted_partner_bank_accounts
FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Policy: Trusted partners can delete/deactivate their own bank accounts
CREATE POLICY "Users can delete own bank accounts"
ON trusted_partner_bank_accounts
FOR DELETE
USING (auth.uid() = user_id);

-- Step 4: Verify only the new policies exist
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM 
    pg_policies
WHERE 
    tablename = 'trusted_partner_bank_accounts'
ORDER BY 
    policyname;

-- Expected result: Should show only 4 policies starting with "Users can..."
-- No "Business owners..." policies should remain
