-- Verify timestamp columns exist in deal_authorizations table
SELECT 
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'deal_authorizations'
  AND column_name IN ('approved_at', 'payment_completed_at', 'completed_at')
ORDER BY column_name;

-- Check current deal authorizations with all timestamps
SELECT 
  id,
  status,
  created_at,
  approved_at,
  payment_completed_at,
  completed_at,
  updated_at
FROM public.deal_authorizations
ORDER BY created_at DESC
LIMIT 10;

-- If columns are missing, run this to add them:
-- ALTER TABLE public.deal_authorizations 
-- ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ,
-- ADD COLUMN IF NOT EXISTS payment_completed_at TIMESTAMPTZ,
-- ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
