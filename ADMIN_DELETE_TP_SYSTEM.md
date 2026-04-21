## Complete Trusted Partner Deletion System - Deployment Guide

This system ensures complete deletion of trusted partners with receipt archival.

### Overview
When an admin deletes a trusted partner:
1. ✅ All receipts are archived to `archived_receipts` table
2. ✅ All deals and deal authorizations are deleted
3. ✅ Business profile is deleted
4. ✅ User profile, membership, QR codes, subscriptions are deleted
5. ✅ User is deleted from Supabase Auth
6. ✅ If they return, they must sign up fresh with OTP verification and terms acceptance

### Deployment Steps

#### Step 1: Create Database Schema and Function
Run [`create_admin_delete_tp_system.sql`](create_admin_delete_tp_system.sql) in Supabase SQL Editor:
```bash
# This creates:
# - archived_receipts table (with RLS policies)
# - admin_delete_trusted_partner() function
# - Proper indexes for performance
```

#### Step 2: Deploy Edge Function for Auth Deletion
The Edge Function [`delete-auth-user`](supabase/functions/delete-auth-user/index.ts) is already created.

Deploy it to Supabase:
```bash
supabase functions deploy delete-auth-user
```

Or via Supabase Dashboard:
1. Go to Edge Functions
2. Create new function named `delete-auth-user`
3. Copy contents from `supabase/functions/delete-auth-user/index.ts`
4. Deploy

#### Step 3: Test the System
```sql
-- In Supabase SQL Editor, test the database function:
SELECT admin_delete_trusted_partner(
    'TRUSTED_PARTNER_USER_ID_HERE'::UUID,
    'Testing deletion system'
);
```

Expected result:
```json
{
  "success": true,
  "trusted_partner_id": "...",
  "trusted_partner_email": "...",
  "receipts_archived": 5,
  "deals_deleted": 3,
  "businesses_deleted": 1,
  "auth_deletion_required": true,
  "message": "Trusted partner deleted from database. Auth user must be deleted separately via Admin SDK."
}
```

### How It Works

#### 1. Database Deletion (via RPC function)
The `admin_delete_trusted_partner()` function:
- Verifies the caller is an admin
- Archives all receipts to `archived_receipts` table
- Deletes in this order:
  1. deal_authorizations
  2. trusted_partner_discounts (deals)
  3. processed_bills
  4. notifications
  5. user_qr_codes
  6. subscriptions
  7. businesses
  8. memberships
  9. profiles

#### 2. Auth Deletion (via Edge Function)
The `delete-auth-user` Edge Function:
- Verifies caller is admin
- Uses Supabase Admin SDK with service role key
- Calls `auth.admin.deleteUser()` to remove from auth.users table

#### 3. App Integration
The updated `AdminService.deleteTrustedPartner()`:
1. Calls database RPC function
2. Calls Edge Function to delete auth user
3. Returns comprehensive result including:
   - Number of receipts archived
   - Number of deals deleted
   - Auth deletion status

### Usage in App

```dart
// In admin dashboard:
final adminService = AdminService();

try {
  final result = await adminService.deleteTrustedPartner(
    trustedPartnerId,
    reason: 'Violation of terms and conditions',
  );
  
  print('Deleted successfully!');
  print('Receipts archived: ${result['receipts_archived']}');
  print('Deals deleted: ${result['deals_deleted']}');
  print('Auth deleted: ${result['auth_deleted']}');
} catch (e) {
  print('Deletion failed: $e');
}
```

### Verification

After deletion, verify:

1. **Archived receipts exist:**
```sql
SELECT COUNT(*) FROM archived_receipts 
WHERE trusted_partner_id = 'DELETED_TP_ID';
```

2. **Database records removed:**
```sql
SELECT COUNT(*) FROM profiles WHERE id = 'DELETED_TP_ID';
-- Should return 0

SELECT COUNT(*) FROM businesses WHERE owner_member_id = 'DELETED_TP_ID';
-- Should return 0

SELECT COUNT(*) FROM trusted_partner_discounts WHERE business_id IN (
    SELECT id FROM businesses WHERE owner_member_id = 'DELETED_TP_ID'
);
-- Should return 0
```

3. **Auth user removed:**
```sql
SELECT COUNT(*) FROM auth.users WHERE id = 'DELETED_TP_ID';
-- Should return 0
```

### What Happens If They Try to Return?

Since the auth user is deleted:
1. They cannot login with old credentials
2. They must sign up as a new user
3. This triggers:
   - Email OTP verification
   - Terms and conditions acceptance
   - Payment for subscription
   - Complete new profile creation

This ensures complete reset with no access to old data.

### Rollback (Recovery from Archive)

If you need to recover a deleted TP's receipts:
```sql
SELECT * FROM archived_receipts 
WHERE trusted_partner_id = 'DELETED_TP_ID'
ORDER BY archived_at DESC;
```

The archive includes:
- All receipt images and data
- Business information
- Member information
- Deal information
- Deletion metadata (who, when, why)

### Security Notes

- ✅ Only users with `role='admin'` in memberships table can delete
- ✅ All operations are logged with admin ID and timestamp
- ✅ Deletion reason is required and stored
- ✅ Edge Function validates admin status before auth deletion
- ✅ RLS policies prevent non-admins from accessing archive

### Troubleshooting

**Edge Function not found:**
- Make sure you deployed it: `supabase functions deploy delete-auth-user`
- Check it exists in Supabase Dashboard > Edge Functions

**Auth deletion fails but database cleaned:**
- This is handled gracefully - database is clean
- Auth user can be manually deleted from Dashboard > Authentication > Users

**Function permission denied:**
- Verify admin user has `role='admin'` in memberships table
- Check RLS policies on archived_receipts table

### Files Modified

1. **Database:** [`create_admin_delete_tp_system.sql`](create_admin_delete_tp_system.sql)
2. **Edge Function:** [`supabase/functions/delete-auth-user/index.ts`](supabase/functions/delete-auth-user/index.ts)
3. **App Service:** [`lib/services/admin_service.dart`](lib/services/admin_service.dart)
