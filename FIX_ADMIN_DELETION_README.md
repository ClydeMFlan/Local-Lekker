# Admin Member Deletion Fix

## Problem
When an admin deletes a member from the app:
- The member is removed from the admin UI
- The member's data is deleted from the database
- **BUT** the member still exists in `auth.users` table
- An error message appears during deletion

## Root Cause
The SQL function `admin_delete_member()` attempts to delete from `auth.users`:
```sql
DELETE FROM auth.users WHERE id = member_user_id;
```

This fails because:
1. SQL functions cannot directly delete from `auth.users` due to Row Level Security (RLS) policies
2. Even with `SECURITY DEFINER`, the function lacks the necessary privileges
3. Supabase requires using the Admin API to delete auth users

## Solution
Split the deletion into two steps:

### 1. Database Changes (SQL)
- Created `admin_delete_member_data()` - deletes all member data EXCEPT auth.users
- Created `admin_delete_trusted_partner_data()` - deletes all TP data EXCEPT auth.users
- Updated old functions for backward compatibility

### 2. Application Changes (Dart)
Updated `lib/services/admin_service.dart`:
```dart
Future<Map<String, dynamic>> deleteMember(String memberId) async {
  // Step 1: Delete all related data via RPC
  final response = await supabase.rpc(
    'admin_delete_member_data',
    params: {'member_user_id': memberId},
  );
  
  // Step 2: Delete auth user via Admin API
  await supabase.auth.admin.deleteUser(memberId);
  
  return response;
}
```

## Files Changed
1. `lib/services/admin_service.dart` - Updated deleteMember() and deleteTrustedPartner()
2. `admin_delete_functions.sql` - Updated SQL functions
3. `fix_admin_member_deletion.sql` - Migration file to apply the fix

## How to Apply
1. Run the migration: `fix_admin_member_deletion.sql`
2. The Dart code changes are already applied
3. Test by deleting a member - they should now be completely removed including from auth.users

## Verification
After deletion, verify the user is gone:
```sql
SELECT * FROM auth.users WHERE id = 'user-id-here';  -- Should return nothing
SELECT * FROM profiles WHERE id = 'user-id-here';    -- Should return nothing
```
