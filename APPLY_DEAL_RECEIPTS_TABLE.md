# Apply Deal Receipts Table Migration

## Issue
The app is trying to save payment receipts to `public.deal_receipts` table, but it doesn't exist yet.

**Error**: `Could not find the table 'public.deal_receipts' in the schema cache, code: PGRST205`

## Solution
Apply the SQL migration to create the table in Supabase.

### Steps to Apply Migration

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project: `local_lekker`

2. **Navigate to SQL Editor**
   - Click on **SQL Editor** in the left sidebar
   - Click **New Query**

3. **Copy and Paste the SQL**
   - Open the file: `create_deal_receipts_table.sql`
   - Copy the entire contents
   - Paste into the SQL Editor

4. **Run the Migration**
   - Click **Run** button (or press `Ctrl+Enter`)
   - Wait for success message
   - You should see: "Success. No rows returned"

5. **Verify Table Created**
   - Go to **Table Editor** in left sidebar
   - Look for `deal_receipts` table
   - Should show columns: id, deal_authorization_id, member_id, receipt_number, amount, etc.

### What This Migration Does

✅ Creates `deal_receipts` table with proper schema
✅ Adds foreign key constraints to:
   - `deal_authorizations` (ON DELETE CASCADE)
   - `auth.users` for member_id and trusted_partner_id
   - `businesses` (ON DELETE SET NULL)
✅ Creates indexes for performance
✅ Enables Row Level Security (RLS)
✅ Adds RLS policies for:
   - Members can view their own receipts
   - Trusted partners can view their business receipts
   - System can insert receipts
   - Admin can view all receipts
✅ Adds `payment_completed_at` column to `deal_authorizations` if missing
✅ Creates trigger for `updated_at` timestamp

### After Migration

Once applied, the payment flow will work:
1. Member completes payment via Paystack
2. Paystack shows success page (will be auto-detected)
3. App displays custom success overlay with "Return to Home" button
4. Clicking button generates receipt and saves to `deal_receipts` table
5. Returns to Members Home Page

### Test the Fix

1. Hot reload the app: `r`
2. Authorize a deal as member
3. Complete payment with test card
4. Wait for automatic success detection (or click if polling fails)
5. Click "Return to Home" button
6. Should see green SnackBar: "Receipt generated successfully!"
7. Check `deal_receipts` table in Supabase to verify receipt saved
