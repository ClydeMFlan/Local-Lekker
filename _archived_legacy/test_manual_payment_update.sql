-- Debug the specific payment update issue

-- 1. Get the deal that's failing (the one shown in Approved tab)
SELECT 
  id,
  member_id,
  business_id,
  trusted_partner_id,
  discount_id,
  status,
  payment_method,
  authorization_type,
  amount,
  created_at,
  approved_at,
  payment_completed_at,
  completed_at
FROM deal_authorizations
WHERE status = 'approved'
  AND payment_completed_at IS NULL
ORDER BY created_at DESC
LIMIT 3;

-- 2. Check if business_id column exists (might be the issue)
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'deal_authorizations'
  AND column_name = 'business_id';

-- 3. Try a manual test update on the most recent approved deal
-- Get the ID first:
DO $$
DECLARE
  test_deal_id UUID;
BEGIN
  SELECT id INTO test_deal_id
  FROM deal_authorizations
  WHERE status = 'approved'
    AND payment_completed_at IS NULL
  ORDER BY created_at DESC
  LIMIT 1;
  
  IF test_deal_id IS NOT NULL THEN
    RAISE NOTICE 'Found deal ID: %', test_deal_id;
    
    -- Try the same update the app is doing
    UPDATE deal_authorizations
    SET 
      payment_completed_at = NOW(),
      updated_at = NOW()
    WHERE id = test_deal_id;
    
    RAISE NOTICE 'Update successful!';
  ELSE
    RAISE NOTICE 'No approved deals found';
  END IF;
END $$;

-- 4. Verify the update worked
SELECT 
  id,
  status,
  payment_completed_at,
  updated_at
FROM deal_authorizations
WHERE status = 'approved'
ORDER BY updated_at DESC
LIMIT 1;
