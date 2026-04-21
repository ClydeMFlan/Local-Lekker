-- COMPLETE DEAL FLOW SIMULATION TEST
-- This simulates what happens when a member completes payment and receipt is generated

-- ==============================================================================
-- STEP 1: Get member and trusted partner IDs
-- ==============================================================================
DO $$
DECLARE
  v_member_id UUID;
  v_trusted_partner_id UUID;
  v_business_id UUID;
  v_discount_id UUID;
  v_deal_id UUID;
  v_receipt_number TEXT;
  v_virtual_receipt_id UUID;
  v_deal_receipt_id UUID;
BEGIN
  -- Get member ID (clydemflan@gmail.com)
  SELECT id INTO v_member_id 
  FROM profiles 
  WHERE email = 'clydemflan@gmail.com';
  
  IF v_member_id IS NULL THEN
    RAISE EXCEPTION 'Member not found: clydemflan@gmail.com';
  END IF;
  
  RAISE NOTICE '✅ Member ID: %', v_member_id;
  
  -- Get trusted partner ID (from businesses table via Momsies)
  SELECT owner_member_id INTO v_trusted_partner_id
  FROM businesses
  WHERE name = 'Momsies';
  
  IF v_trusted_partner_id IS NULL THEN
    RAISE EXCEPTION 'Trusted partner not found for Momsies';
  END IF;
  
  RAISE NOTICE '✅ Trusted Partner ID: %', v_trusted_partner_id;
  
  -- Get business ID (Momsies)
  SELECT id INTO v_business_id
  FROM businesses
  WHERE name = 'Momsies';
  
  IF v_business_id IS NULL THEN
    RAISE EXCEPTION 'Business not found: Momsies';
  END IF;
  
  RAISE NOTICE '✅ Business ID: %', v_business_id;
  
  -- Get or create a discount from Momsies
  SELECT id INTO v_discount_id
  FROM trusted_partner_discounts
  WHERE business_id = v_business_id
  LIMIT 1;
  
  IF v_discount_id IS NULL THEN
    -- Create a test discount with BOTH business_id and trusted_partner_id
    INSERT INTO trusted_partner_discounts (
      business_id,
      trusted_partner_id,
      name,
      description,
      item_name,
      item_price,
      percentage,
      is_active
    ) VALUES (
      v_business_id,
      v_trusted_partner_id,
      'Test Discount',
      'Test discount for receipt generation',
      'Any Item',
      0,
      10,
      true
    )
    RETURNING id INTO v_discount_id;
    RAISE NOTICE '✅ Created new discount: %', v_discount_id;
  END IF;
  
  RAISE NOTICE '✅ Discount ID: %', v_discount_id;

  -- ==============================================================================
  -- STEP 2: Create a test deal authorization (simulate member requesting deal)
  -- ==============================================================================
  INSERT INTO deal_authorizations (
    member_id,
    trusted_partner_id,
    discount_id,
    amount,
    status
  ) VALUES (
    v_member_id,
    v_trusted_partner_id,
    v_discount_id,
    150.00,
    'pending'
  )
  RETURNING id INTO v_deal_id;
  
  RAISE NOTICE '✅ STEP 2: Created deal authorization: %', v_deal_id;
  
  -- ==============================================================================
  -- STEP 3: Simulate trusted partner approving the deal
  -- ==============================================================================
  UPDATE deal_authorizations
  SET 
    status = 'approved',
    approved_at = NOW(),
    updated_at = NOW()
  WHERE id = v_deal_id;
  
  RAISE NOTICE '✅ STEP 3: Deal approved with approved_at timestamp';
  
  -- ==============================================================================
  -- STEP 4: Simulate member completing payment (UPDATE as member)
  -- ==============================================================================
  -- This simulates what happens when member clicks "I Completed Payment ✓"
  UPDATE deal_authorizations
  SET 
    payment_completed_at = NOW(),
    updated_at = NOW()
  WHERE id = v_deal_id;
  
  RAISE NOTICE '✅ STEP 4: Payment completed with payment_completed_at timestamp';
  
  -- ==============================================================================
  -- STEP 5: Generate sequential receipt number
  -- ==============================================================================
  SELECT get_next_receipt_number(v_business_id) INTO v_receipt_number;
  
  RAISE NOTICE '✅ STEP 5: Generated receipt number: %', v_receipt_number;
  
  -- ==============================================================================
  -- STEP 6: Insert into virtual_receipts (member's receipt)
  -- ==============================================================================
  INSERT INTO virtual_receipts (
    deal_authorization_id,
    receipt_number,
    receipt_data,
    qr_code
  ) VALUES (
    v_deal_id,
    v_receipt_number,
    jsonb_build_object(
      'receipt_number', v_receipt_number,
      'deal_authorization_id', v_deal_id,
      'business_name', 'Momsies',
      'business_id', v_business_id,
      'member_name', 'Clyde Flanagan',
      'member_email', 'clydemflan@gmail.com',
      'discount_name', 'Test Discount',
      'amount', 150.00,
      'payment_method', 'in_app',
      'transaction_date', NOW()::text,
      'status', 'completed'
    ),
    'RECEIPT:' || v_deal_id::text || ':' || v_receipt_number
  )
  RETURNING id INTO v_virtual_receipt_id;
  
  RAISE NOTICE '✅ STEP 6: Created virtual_receipt: %', v_virtual_receipt_id;
  
  -- ==============================================================================
  -- STEP 7: Insert into deal_receipts (trusted partner's receipt)
  -- ==============================================================================
  INSERT INTO deal_receipts (
    member_id,
    trusted_partner_id,
    deal_authorization_id,
    receipt_number,
    amount,
    business_name,
    discount_name,
    member_name,
    member_email,
    payment_method
  ) VALUES (
    v_member_id,
    v_trusted_partner_id,
    v_deal_id,
    v_receipt_number,
    150.00,
    'Momsies',
    'Test Discount',
    'Clyde Flanagan',
    'clydemflan@gmail.com',
    'in_app'
  )
  RETURNING id INTO v_deal_receipt_id;
  
  RAISE NOTICE '✅ STEP 7: Created deal_receipt: %', v_deal_receipt_id;
  
  -- ==============================================================================
  -- STEP 8: Verify all data
  -- ==============================================================================
  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE '✅✅✅ FULL FLOW COMPLETED SUCCESSFULLY';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Deal ID: %', v_deal_id;
  RAISE NOTICE 'Receipt Number: %', v_receipt_number;
  RAISE NOTICE 'Virtual Receipt ID: %', v_virtual_receipt_id;
  RAISE NOTICE 'Deal Receipt ID: %', v_deal_receipt_id;
  RAISE NOTICE '';
  
  -- Clean up test data (comment out if you want to keep it)
  -- DELETE FROM deal_receipts WHERE id = v_deal_receipt_id;
  -- DELETE FROM virtual_receipts WHERE id = v_virtual_receipt_id;
  -- DELETE FROM deal_authorizations WHERE id = v_deal_id;
  -- RAISE NOTICE '🧹 Test data cleaned up';
  
END $$;

-- ==============================================================================
-- VERIFICATION QUERIES
-- ==============================================================================

-- Show the test deal
SELECT 
  '🔍 TEST DEAL' as info,
  id,
  status,
  amount,
  approved_at,
  payment_completed_at,
  completed_at,
  created_at
FROM deal_authorizations
WHERE member_id = (SELECT id FROM profiles WHERE email = 'clydemflan@gmail.com')
ORDER BY created_at DESC
LIMIT 1;

-- Show receipts for member
SELECT 
  '🧾 MEMBER RECEIPTS' as info,
  COUNT(*) as total_virtual_receipts
FROM virtual_receipts vr
JOIN deal_authorizations da ON vr.deal_authorization_id = da.id
WHERE da.member_id = (SELECT id FROM profiles WHERE email = 'clydemflan@gmail.com');

-- Show receipts for trusted partner
SELECT 
  '📋 PARTNER RECEIPTS' as info,
  COUNT(*) as total_deal_receipts
FROM deal_receipts
WHERE trusted_partner_id = (SELECT owner_member_id FROM businesses WHERE name = 'Momsies');

-- Show the actual receipt details
SELECT 
  '📄 RECEIPT DETAILS' as info,
  dr.receipt_number,
  dr.business_name,
  dr.member_name,
  dr.amount,
  dr.payment_method,
  dr.created_at
FROM deal_receipts dr
WHERE dr.member_id = (SELECT id FROM profiles WHERE email = 'clydemflan@gmail.com')
ORDER BY dr.created_at DESC
LIMIT 1;
