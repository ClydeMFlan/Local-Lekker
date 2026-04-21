-- Fix script for deal_authorizations table
-- Only run this AFTER reviewing the verification script results

-- STEP 1: Ensure all required columns exist
DO $$
BEGIN
    -- Add business_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'deal_authorizations'
        AND column_name = 'business_id'
    ) THEN
        ALTER TABLE deal_authorizations ADD COLUMN business_id UUID;
        RAISE NOTICE 'Added business_id column';
    END IF;

    -- Add trusted_partner_id if missing
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'deal_authorizations'
        AND column_name = 'trusted_partner_id'
    ) THEN
        ALTER TABLE deal_authorizations ADD COLUMN trusted_partner_id UUID;
        RAISE NOTICE 'Added trusted_partner_id column';
    END IF;
END $$;

-- STEP 2: Fix any existing records where trusted_partner_id is a user ID instead of business ID
-- This updates trusted_partner_id to match business_id
UPDATE deal_authorizations
SET trusted_partner_id = business_id
WHERE trusted_partner_id IS NULL 
   OR trusted_partner_id != business_id
   OR trusted_partner_id IN (SELECT id FROM profiles);

-- STEP 3: Drop and recreate foreign key constraints to ensure they're correct
ALTER TABLE deal_authorizations 
DROP CONSTRAINT IF EXISTS deal_authorizations_business_id_fkey;

ALTER TABLE deal_authorizations 
DROP CONSTRAINT IF EXISTS deal_authorizations_trusted_partner_id_fkey;

ALTER TABLE deal_authorizations 
DROP CONSTRAINT IF EXISTS deal_authorizations_member_id_fkey;

ALTER TABLE deal_authorizations 
DROP CONSTRAINT IF EXISTS deal_authorizations_discount_id_fkey;

-- STEP 4: Add correct foreign key constraints
ALTER TABLE deal_authorizations 
ADD CONSTRAINT deal_authorizations_business_id_fkey
FOREIGN KEY (business_id) 
REFERENCES businesses(id) 
ON DELETE CASCADE;

ALTER TABLE deal_authorizations 
ADD CONSTRAINT deal_authorizations_trusted_partner_id_fkey
FOREIGN KEY (trusted_partner_id) 
REFERENCES businesses(id) 
ON DELETE CASCADE;

ALTER TABLE deal_authorizations 
ADD CONSTRAINT deal_authorizations_member_id_fkey
FOREIGN KEY (member_id) 
REFERENCES profiles(id) 
ON DELETE CASCADE;

ALTER TABLE deal_authorizations 
ADD CONSTRAINT deal_authorizations_discount_id_fkey
FOREIGN KEY (discount_id) 
REFERENCES trusted_partner_discounts(id) 
ON DELETE SET NULL;

-- STEP 5: Verify the fixes
SELECT
    tc.constraint_name,
    kcu.column_name,
    ccu.table_name AS foreign_table,
    ccu.column_name AS foreign_column,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
LEFT JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'deal_authorizations'
ORDER BY kcu.column_name;

-- STEP 6: Final check - show any remaining issues
SELECT 
    COUNT(*) FILTER (WHERE trusted_partner_id IS NULL) as null_tp_id,
    COUNT(*) FILTER (WHERE business_id IS NULL) as null_business_id,
    COUNT(*) FILTER (WHERE trusted_partner_id != business_id) as mismatched_ids,
    COUNT(*) as total
FROM deal_authorizations;
