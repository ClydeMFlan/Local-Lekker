# Trusted Partner Payment Flow Migration

This migration adds the complete trusted partner payment flow functionality to the Local Lekker application.

## What's Added

### Database Changes

1. **processed_bills table enhancements:**
   - `approval_status`: Tracks approval state ('pending', 'approved', 'rejected')
   - `approved_at`: Timestamp when bill was approved
   - `approved_by`: User ID who approved the bill
   - `rejection_reason`: Reason for rejection (if applicable)
   - `payment_method`: How payment was made ('pending', 'in_app', 'physical')
   - `payment_id`: Reference to payment record

2. **trusted_partner_bank_accounts table:**
   - Stores bank account information for trusted partners
   - Includes PayFast merchant credentials for in-app payments
   - RLS policies ensure business owners can only access their accounts

3. **bill_approvals table:**
   - Tracks the approval workflow between members and partners
   - Links bills to partners for review
   - Includes approval status and review notes

4. **Triggers and Functions:**
   - Automatic approval record creation when bills are processed
   - Status synchronization between approvals and bills
   - Automatic timestamp updates

## How to Apply

### Option 1: Using Supabase CLI (Recommended)

If you have a local Supabase instance:

```bash
# Start Supabase (if not already running)
supabase start

# Apply the migration
supabase db push
```

### Option 2: Manual SQL Execution

1. Connect to your Supabase database using your preferred SQL client
2. Run the `apply_payment_flow_migration.sql` script
3. Verify the migration with `verify_payment_flow_migration.sql`

### Option 3: Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to the SQL Editor
3. Copy and paste the contents of `apply_payment_flow_migration.sql`
4. Execute the script
5. Run the verification script to confirm success

## Verification

After applying the migration, run `verify_payment_flow_migration.sql` to ensure:

- All tables were created with correct columns
- RLS policies are properly configured
- Triggers and functions are installed
- Indexes are created for performance

## Rollback

If you need to rollback this migration:

```sql
-- Drop tables (cascade will handle dependencies)
DROP TABLE IF EXISTS bill_approvals CASCADE;
DROP TABLE IF EXISTS trusted_partner_bank_accounts CASCADE;

-- Remove added columns from processed_bills
ALTER TABLE processed_bills DROP COLUMN IF EXISTS approval_status;
ALTER TABLE processed_bills DROP COLUMN IF EXISTS approved_at;
ALTER TABLE processed_bills DROP COLUMN IF EXISTS approved_by;
ALTER TABLE processed_bills DROP COLUMN IF EXISTS rejection_reason;
ALTER TABLE processed_bills DROP COLUMN IF EXISTS payment_method;
ALTER TABLE processed_bills DROP COLUMN IF EXISTS payment_id;
```

## Testing

After migration:

1. Create a trusted partner account
2. Set up bank account details in business profile
3. Have a member scan a bill at the partner's business
4. Check that approval records are created automatically
5. Test the approval workflow in the Bill Approvals page
6. Verify payment processing works for both in-app and physical payments

## Files Included

- `apply_payment_flow_migration.sql` - The main migration script
- `verify_payment_flow_migration.sql` - Verification script
- `supabase/migrations/20250925193346_add_trusted_partner_payment_flow.sql` - Original migration file