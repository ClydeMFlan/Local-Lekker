# Trusted Partner Deletion System - Complete Setup

## ✅ What's Ready

### 1. Database Components
- **Archive Tables Created:** `archived_receipts`, `archived_paystack_data`, `archived_pending_payments`
- **Deletion Function:** `admin_delete_trusted_partner(target_user_id, deletion_reason)`
- **File:** [create_admin_delete_tp_system.sql](create_admin_delete_tp_system.sql)

**Run in Supabase SQL Editor:**
```sql
-- Run all statements in create_admin_delete_tp_system.sql
```

### 2. Edge Function (Auth Deletion)
- **Function Location:** `supabase/functions/delete-auth-user/index.ts`
- **Updated:** Now checks `memberships` table for admin role (not just email)
- **File:** [EDGE_FUNCTION_DEPLOYMENT.md](EDGE_FUNCTION_DEPLOYMENT.md)

**Deploy with:**
```bash
supabase functions deploy delete-auth-user
```

### 3. Dart Service Layer
- **File:** `lib/services/admin_service.dart`
- **Method:** `deleteTrustedPartner(String tpUserId, {String reason})`
- **Status:** Ready to use ✅

**Usage in UI:**
```dart
final result = await AdminService().deleteTrustedPartner(
  'trusted-partner-uuid',
  reason: 'Violation of terms of service'
);
```

## 📋 Step-by-Step Deployment

### Step 1: Run SQL Migration
1. Go to [Supabase Console](https://app.supabase.com) → Your Project → SQL Editor
2. Copy entire contents of [create_admin_delete_tp_system.sql](create_admin_delete_tp_system.sql)
3. Paste into SQL Editor and click "Run"
4. Verify success: Archive tables created, function created

### Step 2: Deploy Edge Function
1. Open terminal in project root
2. Run: `supabase functions deploy delete-auth-user`
3. Verify output shows: `✓ Function delete-auth-user deployed successfully!`

### Step 3: Verify Everything Works
1. Login as admin in your app
2. Navigate to Trusted Partners management
3. Try deleting a test trusted partner
4. Verify:
   - Trusted partner deleted from database
   - Receipts archived in `archived_receipts`
   - Paystack data archived in `archived_paystack_data`
   - Pending payments archived and deleted
   - User deleted from Supabase Auth (can't login)

## 🔄 Complete Deletion Flow

```
Admin clicks "Delete Trusted Partner"
         ↓
AdminService.deleteTrustedPartner() called
         ↓
Database Function: admin_delete_trusted_partner()
  ├─ Archive Paystack data
  ├─ Archive pending payments
  ├─ Archive receipts
  ├─ Delete deals/discounts
  ├─ Delete business
  ├─ Delete from profiles & memberships
  └─ Return JSON summary
         ↓
Edge Function: delete-auth-user
  ├─ Verify caller is admin
  ├─ Delete from auth.users
  └─ Return success status
         ↓
Admin sees success message
Trusted Partner is completely removed
```

## 📊 What Gets Archived

### archived_receipts
- Receipt images and bill data
- Discount information
- Total amounts
- Member information
- Original timestamps

### archived_paystack_data
- Paystack recipient codes
- Paystack authorization codes
- Paystack subaccount codes
- Bank information
- Account details

### archived_pending_payments
- Payment amounts and currency
- Paystack references
- Member IDs and emails
- Payment status
- Expiration dates

## 🔐 Security

✅ **Admin-Only:** Function checks `memberships.role = 'admin'`
✅ **Audit Trail:** All deletions logged with admin ID, reason, and timestamp
✅ **Service Role Protected:** Auth deletion uses Supabase Service Role Key
✅ **RLS Policies:** Archive tables only accessible to admins

## 🧪 Testing the Deletion

### Option 1: Manual Test (Recommended)
1. Create a test trusted partner account
2. Have the partner login and generate some activity:
   - Create a business
   - Add some deals
   - Process some receipts
3. Login as admin
4. Delete the test partner
5. Verify in database:
   - Archives have the data
   - Original tables are cleaned
   - User can't login

### Option 2: Direct SQL Query
```sql
-- Call the deletion function directly
SELECT admin_delete_trusted_partner(
  'TRUSTED_PARTNER_UUID_HERE'::UUID,
  'Testing deletion system'
);

-- Check archive tables
SELECT COUNT(*) FROM archived_receipts;
SELECT COUNT(*) FROM archived_paystack_data;
SELECT COUNT(*) FROM archived_pending_payments;
```

## 📖 Documentation Files

- [EDGE_FUNCTION_DEPLOYMENT.md](EDGE_FUNCTION_DEPLOYMENT.md) - Detailed Edge Function guide
- [create_admin_delete_tp_system.sql](create_admin_delete_tp_system.sql) - Database migration SQL
- [lib/services/admin_service.dart](lib/services/admin_service.dart) - Dart service implementation
- [supabase/functions/delete-auth-user/index.ts](supabase/functions/delete-auth-user/index.ts) - Edge Function code

## ⚠️ Important Notes

1. **Irreversible:** Trusted partner deletion is permanent. Archive tables are for auditing only.
2. **Auth Deletion:** User is deleted from `auth.users` and cannot login
3. **Re-signup:** If user tries to re-signup, they'll get a new account (old is gone)
4. **Payment Handling:** Pending payments are archived but deleted from `payments` table
5. **Receipts:** Member receipts are archived but no longer visible to TP or admin through normal UI

## ✨ Next Steps

1. ✅ Run the SQL migration
2. ✅ Deploy the Edge Function
3. ✅ Test with a non-critical trusted partner
4. ✅ Monitor archive tables to ensure data is being stored
5. ✅ Add admin UI to view archived data (future enhancement)
