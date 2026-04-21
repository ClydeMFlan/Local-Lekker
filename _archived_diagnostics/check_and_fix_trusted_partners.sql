-- Comprehensive check and fix for trusted_partners table Paystack integration

-- First, check if the table exists and what columns it has
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'trusted_partners';

-- Check current columns in trusted_partners table
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'trusted_partners'
ORDER BY ordinal_position;

-- Add the missing paystack_subaccount_id column if it doesn't exist
ALTER TABLE public.trusted_partners
ADD COLUMN IF NOT EXISTS paystack_subaccount_id TEXT;

-- Add comment for documentation
COMMENT ON COLUMN public.trusted_partners.paystack_subaccount_id IS 'Paystack subaccount ID for split payments (secure token)';

-- Create index for performance
CREATE INDEX IF NOT EXISTS idx_trusted_partners_paystack_subaccount_id ON public.trusted_partners(paystack_subaccount_id);

-- Verify the column was added successfully
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'trusted_partners'
AND column_name = 'paystack_subaccount_id';