# User Deletion Cascade System

This SQL script provides automatic and manual user deletion functionality for the Local Lekker application.

## Features

- **Automatic Deletion**: When a user is deleted from Supabase Auth, all associated data is automatically cleaned up
- **Manual Deletion**: Admin function to manually delete users and all their data
- **Comprehensive Cleanup**: Handles all user-related tables in the correct dependency order
- **Logging**: Detailed logging of deletion operations
- **Error Handling**: Proper error handling and rollback on failures

## Tables Cleaned Up

The script deletes data from these tables in the correct order:

1. `virtual_receipts` (via deal authorizations)
2. `deal_receipts`
3. `notifications`
4. `deal_authorizations`
5. `processed_bills`
6. `payments`
7. `user_qr_codes`
8. `subscriptions`
9. `memberships`
10. `trusted_partner_bank_accounts`
11. `businesses` (cascades to related tables)
12. `trusted_partners`
13. `profiles`
14. `auth.users`

## Installation

Run the `delete_user_cascade.sql` script in your Supabase SQL editor or via the CLI:

```bash
psql -h your-db-host -U postgres -d postgres -f delete_user_cascade.sql
```

Or copy and paste the contents into the Supabase SQL Editor.

## Usage

### Automatic Deletion (Recommended)

When you delete a user from the Supabase Auth dashboard:
1. Go to Authentication → Users
2. Select the user to delete
3. Click "Delete user"
4. All associated data is automatically cleaned up by the trigger

### Manual Deletion (Admin Function)

For programmatic deletion or admin operations:

```sql
-- Delete a user and all their data
SELECT admin_delete_user('user-uuid-here');
```

Example response:
```
"User and all associated data successfully deleted"
```

### Check User Data Before Deletion

Before deleting a user, you can check what data exists:

```sql
SELECT
    (SELECT COUNT(*) FROM profiles WHERE id = 'user-uuid') as profiles,
    (SELECT COUNT(*) FROM trusted_partners WHERE user_id = 'user-uuid') as trusted_partners,
    (SELECT COUNT(*) FROM businesses WHERE owner_member_id = 'user-uuid') as businesses,
    (SELECT COUNT(*) FROM subscriptions WHERE user_id = 'user-uuid') as subscriptions,
    (SELECT COUNT(*) FROM payments WHERE user_id = 'user-uuid') as payments,
    (SELECT COUNT(*) FROM notifications WHERE user_id = 'user-uuid') as notifications,
    (SELECT COUNT(*) FROM deal_authorizations WHERE member_id = 'user-uuid' OR trusted_partner_id = 'user-uuid') as deal_authorizations;
```

## Security Considerations

- The trigger function runs with `SECURITY DEFINER` to access auth.users
- The admin function is granted to `authenticated` users (consider restricting to specific roles)
- All operations are logged for audit purposes
- Foreign key constraints are respected during deletion

## Error Handling

- If automatic deletion fails, the user remains in auth.users but associated data may be partially deleted
- Manual deletion provides detailed error messages
- All operations include proper exception handling

## Testing

Test the system with a test user:

1. Create a test user account
2. Add some data (business, deals, payments, etc.)
3. Delete the user from Supabase Auth
4. Verify all associated data is cleaned up
5. Check the logs for deletion details

## Maintenance

- Monitor the PostgreSQL logs for deletion operations
- Regularly review the deletion order if new tables are added
- Test the system after schema changes
- Consider adding soft delete options for audit-critical data