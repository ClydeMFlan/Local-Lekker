# EXECUTE THIS SQL IN SUPABASE SQL EDITOR

## ⚠️ CRITICAL: This SQL MUST be executed before testing receipts ⚠️

The sequential receipt numbering feature requires this database schema to be applied.

## Instructions:

1. Open Supabase Dashboard: https://supabase.com/dashboard/project/qdrotavcmmevhgveodcp
2. Go to SQL Editor (left sidebar)
3. Click "New Query"
4. Copy and paste the SQL below
5. Click "Run" (or press Ctrl+Enter)
6. Verify success message

---

## SQL to Execute:

```sql
-- Add receipt_counter column to businesses table
-- This tracks the next receipt number for each business
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS receipt_counter INTEGER DEFAULT 0;

-- Create function to generate sequential receipt numbers
-- Format: TP-{3-CHAR-PREFIX}-{5-DIGIT-COUNTER}
-- Example: TP-MOM-00001 for Momsies business
CREATE OR REPLACE FUNCTION public.get_next_receipt_number(p_business_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_counter INTEGER;
    v_business_prefix TEXT;
BEGIN
    -- Lock the business row and get current counter + name prefix
    -- FOR UPDATE prevents concurrent transactions from getting same number
    SELECT receipt_counter, UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO v_counter, v_business_prefix
    FROM public.businesses
    WHERE id = p_business_id
    FOR UPDATE;
    
    -- Increment counter (starts at 0, so first receipt will be 1)
    v_counter := COALESCE(v_counter, 0) + 1;
    
    -- Update the counter in the database
    UPDATE public.businesses
    SET receipt_counter = v_counter
    WHERE id = p_business_id;
    
    -- Return formatted receipt number
    -- LPAD adds leading zeros: 1 -> 00001
    RETURN 'TP-' || v_business_prefix || '-' || LPAD(v_counter::TEXT, 5, '0');
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_next_receipt_number(UUID) TO authenticated;
```

---

## Verification:

After executing, run these queries to verify:

```sql
-- 1. Check that businesses table has receipt_counter column
SELECT id, name, receipt_counter 
FROM businesses 
LIMIT 5;
-- Expected: Should show receipt_counter column with value 0 for all businesses

-- 2. Test the function with Momsies business ID
SELECT get_next_receipt_number('8692b21b-42c4-43fd-af23-fb0f37bc4068');
-- Expected result: TP-MOM-00001

-- 3. Call again to verify counter increments
SELECT get_next_receipt_number('8692b21b-42c4-43fd-af23-fb0f37bc4068');
-- Expected result: TP-MOM-00002

-- 4. Check that counter was updated in database
SELECT name, receipt_counter 
FROM businesses 
WHERE id = '8692b21b-42c4-43fd-af23-fb0f37bc4068';
-- Expected: receipt_counter should be 2 (since we called function twice)
```

---

## What This Does:

1. **Adds `receipt_counter` column**: Tracks the next sequential number for each business
2. **Creates database function**: Generates receipt numbers in format TP-{PREFIX}-{COUNTER}
3. **Row-level locking**: Uses `FOR UPDATE` to prevent duplicate numbers in concurrent transactions
4. **Automatic increment**: Each call increments the counter by 1
5. **Grant permissions**: Allows authenticated users (trusted partners) to call the function

## Format Examples:

| Business | Prefix | Counter | Receipt Number |
|----------|--------|---------|----------------|
| Momsies | MOM | 1 | TP-MOM-00001 |
| Momsies | MOM | 2 | TP-MOM-00002 |
| Spar | SPA | 1 | TP-SPA-00001 |
| Pick n Pay | PIC | 1 | TP-PIC-00001 |

## Troubleshooting:

**Error: "column receipt_counter already exists"**
- The column was added previously. This is OK - the `IF NOT EXISTS` prevents errors.
- The function will still be created/updated.

**Error: "function already exists"**
- The `CREATE OR REPLACE` will update the existing function. This is normal.

**Function returns null or error**
- Check that the business_id exists in the businesses table
- Check that the user calling the function has authenticated role

**Counter doesn't increment**
- Make sure you're calling the function (it updates the database each time)
- Don't just SELECT receipt_counter - call get_next_receipt_number()

---

## After SQL Execution:

✅ Sequential receipt numbering is ready!
✅ Hot reload the Flutter app
✅ Test receipt generation
✅ Verify receipt number shows as TP-MOM-00001 (not timestamp)

See `RECEIPT_ENHANCEMENTS_COMPLETED.md` for full testing instructions.
