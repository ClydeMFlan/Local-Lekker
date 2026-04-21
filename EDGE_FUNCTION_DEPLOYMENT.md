# Edge Function Deployment Guide

## Overview
The `delete-auth-user` Edge Function handles secure deletion of users from Supabase Authentication when admins delete a Trusted Partner. It's called by the Flutter app after database cleanup is completed.

## Function Location
```
supabase/functions/delete-auth-user/index.ts
```

## What the Function Does
1. **Validates Authentication** - Checks that the request has a valid Bearer token
2. **Verifies Admin Status** - Looks up the caller in the `memberships` table to confirm `role = 'admin'`
3. **Deletes Auth User** - Uses the Supabase Service Role key to delete the user from `auth.users`
4. **Returns Response** - Returns JSON with success status and details

## Prerequisites
- Supabase CLI installed: `npm install -g supabase`
- Access to your Supabase project
- Your Supabase project URL and Service Role Key

## Deployment Steps

### 1. Verify the Function File
Make sure the function exists at: `supabase/functions/delete-auth-user/index.ts`

The function should:
- Check the `memberships` table for admin role ✅
- Use Service Role Key for auth deletion ✅
- Return proper error messages ✅

### 2. Deploy to Supabase
Run this command from the project root:

```bash
supabase functions deploy delete-auth-user
```

### 3. Verify Deployment
After deployment, you should see output like:
```
✓ Function delete-auth-user deployed successfully!
Endpoint: https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/delete-auth-user
```

### 4. Test the Function (Optional)

**Get an Admin Auth Token:**
1. Login to your app as admin
2. Open DevTools → Application → LocalStorage
3. Copy the `sb-access-token` value

**Test via cURL:**
```bash
curl -X POST \
  'https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/delete-auth-user' \
  -H 'Authorization: Bearer YOUR_ADMIN_TOKEN' \
  -H 'Content-Type: application/json' \
  -d '{
    "user_id": "USER_ID_TO_DELETE"
  }'
```

**Expected Successful Response:**
```json
{
  "success": true,
  "deleted_user_id": "...",
  "deleted_by": "...",
  "message": "User successfully deleted from authentication"
}
```

## Configuration

### AdminService (lib/services/admin_service.dart)
The function URL is already configured:
```dart
final String _deleteAuthFunctionUrl =
    'https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/delete-auth-user';
```

If your Supabase URL is different, update this value.

## Complete Deletion Flow

When admin deletes a Trusted Partner via `AdminService.deleteTrustedPartner()`:

1. **Database Deletion** (PostgreSQL Function)
   ```sql
   admin_delete_trusted_partner(target_user_id, deletion_reason)
   ```
   - Archives receipts → `archived_receipts`
   - Archives Paystack data → `archived_paystack_data`
   - Archives payments → `archived_pending_payments`
   - Deletes deals, businesses, subscriptions
   - Clears Paystack fields from profile
   - Deletes from `profiles` and `memberships`

2. **Auth Deletion** (Edge Function)
   ```typescript
   POST /functions/v1/delete-auth-user
   {user_id: "..."}
   ```
   - Verifies admin status via `memberships` table
   - Deletes from `auth.users` using Service Role
   - TP cannot login or re-access old account

## Security Considerations

✅ **Admin-Only Access**
- Function checks `memberships` table for `role = 'admin'`
- Only authenticated users can call it

✅ **Service Role Protection**
- Service Role Key stored in Supabase environment
- Never exposed to client/frontend
- Only used inside Edge Function

✅ **Authorization Header**
- Bearer token from admin user required
- Function validates token is legitimate

✅ **Audit Trail**
- Database function logs `archived_by` (admin ID)
- `deletion_reason` stored in archive tables
- Complete record of who deleted what and when

## Troubleshooting

### Function Not Found (404)
```
POST /functions/v1/delete-auth-user returns 404
```
**Solution:** Ensure function was deployed successfully:
```bash
supabase functions deploy delete-auth-user
```

### Permission Denied (403)
```json
{"error": "Forbidden - caller is not an admin"}
```
**Solution:** 
- Verify caller has `memberships.role = 'admin'`
- Check database has correct admin email in `profiles` table
- Re-authenticate with admin user

### Invalid Token (401)
```json
{"error": "Invalid token or unable to resolve user"}
```
**Solution:**
- Ensure Authorization header is present: `Authorization: Bearer <token>`
- Token must be valid and not expired
- Admin user must be logged into the app

### Internal Server Error (500)
**Solution:**
- Check Supabase logs: Project Settings → Logs → Edge Functions
- Verify `SUPABASE_SERVICE_ROLE_KEY` is set in environment
- Confirm `memberships` table exists and has proper RLS policies

## Redeployment
If you update the function code:
```bash
supabase functions deploy delete-auth-user
```

The function will be updated immediately.

## Related Database Components

- **Schema:** [unified_schema_rls_policies.sql](unified_schema_rls_policies.sql)
- **Deletion Function:** [create_admin_delete_tp_system.sql](create_admin_delete_tp_system.sql)
- **Admin Service:** [lib/services/admin_service.dart](lib/services/admin_service.dart)
- **Admin Dashboard:** [lib/features/admin/admin_dashboard_page.dart](lib/features/admin/admin_dashboard_page.dart)
