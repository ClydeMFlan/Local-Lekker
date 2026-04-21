-- Check current state of deal_authorizations timestamps
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

-- Check if any deals have timestamps set
SELECT 
  COUNT(*) as total_deals,
  COUNT(approved_at) as with_approved_at,
  COUNT(payment_completed_at) as with_payment_completed_at,
  COUNT(completed_at) as with_completed_at
FROM public.deal_authorizations;

-- Test update to verify RLS policies allow updates
-- Replace 'YOUR_DEAL_ID' with an actual deal ID from your table
-- UPDATE public.deal_authorizations
-- SET approved_at = NOW(), updated_at = NOW()
-- WHERE id = 'YOUR_DEAL_ID';
