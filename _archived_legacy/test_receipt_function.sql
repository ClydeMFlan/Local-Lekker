-- Test the sequential receipt number function

-- Test 1: Generate first receipt for Momsies
SELECT get_next_receipt_number('8692b21b-42c4-43fd-af23-fb0f37bc4068') as first_receipt;
-- Expected: TP-MOM-00001

-- Test 2: Check counter was incremented
SELECT name, receipt_counter 
FROM businesses 
WHERE id = '8692b21b-42c4-43fd-af23-fb0f37bc4068';
-- Expected: receipt_counter = 1

-- Test 3: Generate second receipt
SELECT get_next_receipt_number('8692b21b-42c4-43fd-af23-fb0f37bc4068') as second_receipt;
-- Expected: TP-MOM-00002

-- Test 4: Verify counter again
SELECT name, receipt_counter 
FROM businesses 
WHERE id = '8692b21b-42c4-43fd-af23-fb0f37bc4068';
-- Expected: receipt_counter = 2
