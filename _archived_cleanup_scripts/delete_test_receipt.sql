-- Delete the old test receipt so we can regenerate it with new enhancements
-- Receipt Number: RCP-1761040312063

-- First, check what we're about to delete
SELECT 
  id,
  receipt_number,
  member_id,
  deal_authorization_id,
  created_at
FROM deal_receipts
WHERE receipt_number = 'RCP-1761040312063';

-- Also check virtual_receipts
SELECT 
  id,
  deal_authorization_id,
  receipt_data->>'receipt_number' as receipt_number,
  created_at
FROM virtual_receipts
WHERE receipt_data->>'receipt_number' = 'RCP-1761040312063';

-- Delete from deal_receipts
DELETE FROM deal_receipts
WHERE receipt_number = 'RCP-1761040312063';

-- Delete from virtual_receipts
DELETE FROM virtual_receipts
WHERE receipt_data->>'receipt_number' = 'RCP-1761040312063';

-- Verify deletion
SELECT COUNT(*) as remaining_receipts_with_this_number
FROM deal_receipts
WHERE receipt_number = 'RCP-1761040312063';
