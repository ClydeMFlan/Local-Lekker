# Member Deletion & Re-signup Archive System

## Overview
This system enables deleted members to seamlessly re-signup by automatically retrieving and autofilling their previous information from the `archived_members` table.

## How It Works

### Admin Deletes a Member
1. Admin deletes member via Admin Dashboard (`members_list_screen.dart`)
2. `AdminService.deleteMember()` is called
3. Database function `admin_delete_member_data()` executes:
   - **First**: Archives member profile data to `archived_members` table
   - **Then**: Deletes member from all tables (subscriptions, QR codes, payments, etc.)
   - **Finally**: Deletes from `profiles` table
4. Supabase Auth user is deleted via Edge Function

### Member Tries to Sign In
- Email not found in Auth (expected behavior)
- User gets error message prompting to sign up

### Member Re-signs Up
1. Member enters email on signup page
2. Email debounce triggers after 400ms
3. System checks in order:
   - **Active profile** → Redirects to sign-in
   - **Deactivated profile** → Autofills from profile
   - **Archived member** → **Autofills from archive** ✨
4. If archived member found:
   - All form fields autofill (name, surname, address, contact, DOB, gender, ethnicity)
   - Green snackbar shows: "Welcome back! We found your previous details and autofilled the form."
   - Member just needs to enter password and submit

## Database Schema

### `archived_members` Table
```sql
CREATE TABLE public.archived_members (
    id UUID PRIMARY KEY,
    original_user_id UUID NOT NULL,  -- Original auth user ID (now deleted)
    email TEXT NOT NULL,
    name TEXT,
    surname TEXT,
    street TEXT,
    suburb TEXT,
    city TEXT,
    province TEXT,
    contact TEXT,
    gender TEXT,
    ethnicity TEXT,
    date_of_birth TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    deleted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_by UUID REFERENCES auth.users(id),  -- Admin who deleted
    deletion_reason TEXT,
    
    -- Subscription info at deletion
    last_subscription_status TEXT,
    last_subscription_end_date TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Indexes
- `idx_archived_members_email` - Fast email lookup during signup
- `idx_archived_members_original_user_id` - Reference tracking

### RLS Policies
- Admins can view all archived members
- Anon users can read (for signup autofill)
- Authenticated users can insert (via SECURITY DEFINER function)

## Implementation Files

### Database Migration Files
1. **`create_archived_members_table.sql`**
   - Creates `archived_members` table
   - Sets up indexes and RLS policies
   
2. **`update_admin_delete_member_with_archive.sql`**
   - Updates `admin_delete_member_data()` function
   - Archives member data before deletion

### Application Code
1. **`lib/services/supabase_service.dart`**
   - Added `getArchivedMemberByEmail()` method
   - Queries `archived_members` table by email

2. **`lib/features/auth/members_signup_page.dart`**
   - Updated `_onEmailChanged()` to check archived members
   - Added `_prefillFromArchivedMember()` method
   - Shows green success snackbar when archive found

## Deployment Steps

### 1. Deploy Database Changes
Execute SQL files in Supabase SQL Editor in this order:

```bash
# Step 1: Create the archived_members table
# Run: create_archived_members_table.sql

# Step 2: Update the deletion function to archive data
# Run: update_admin_delete_member_with_archive.sql
```

### 2. Verify Database Setup
```sql
-- Check table exists
SELECT * FROM archived_members LIMIT 1;

-- Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename = 'archived_members';

-- Check indexes
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'archived_members';
```

### 3. Deploy Application Code
The Flutter app code is already updated:
- `lib/services/supabase_service.dart`
- `lib/features/auth/members_signup_page.dart`

No additional deployment needed - changes are in codebase.

### 4. Test the Flow

#### Test 1: Admin Deletes Member
1. Login as admin
2. Navigate to Members List
3. Delete member: `bekkerhenno518@gmail.com`
4. Verify member removed from database:
   ```sql
   SELECT * FROM profiles WHERE email = 'bekkerhenno518@gmail.com';
   -- Should return no rows
   
   SELECT * FROM archived_members WHERE email = 'bekkerhenno518@gmail.com';
   -- Should return 1 row with all member data
   ```

#### Test 2: Deleted Member Tries Sign In
1. Go to Welcome Page
2. Click "Sign In"
3. Enter: `bekkerhenno518@gmail.com`
4. Should get error: "User not found" or similar

#### Test 3: Deleted Member Re-signs Up
1. Go to Welcome Page
2. Click "Sign Up as Member"
3. Enter email: `bekkerhenno518@gmail.com`
4. Wait 400ms for debounce
5. **Expected**: 
   - Green snackbar appears: "Welcome back! We found your previous details and autofilled the form."
   - All fields autofill (name, surname, address, contact, DOB, etc.)
6. Enter new password
7. Complete signup

## Architecture Decisions

### Why Archive Instead of Soft Delete?
- **Complete removal** from active tables improves performance
- **Archive table** is separate and optimized for read-only queries
- **RLS policies** keep archived data secure (admin-only view)
- **Anon access** for signup autofill only (no sensitive data exposed)

### Why Check Archive in Signup Flow?
- **Seamless UX**: User doesn't need to re-enter all details
- **Data consistency**: Ensures returning members use same profile data
- **Trust building**: Shows platform remembers the user

### Security Considerations
- Archived data accessible to anon for autofill (acceptable - no payment/subscription data)
- Only profile fields autofill (no passwords or payment info)
- Admin who deleted is tracked (`deleted_by` field)
- Deletion reason stored for audit trail

## Monitoring & Maintenance

### Check Archive Growth
```sql
SELECT 
    COUNT(*) as total_archived_members,
    COUNT(*) FILTER (WHERE deleted_at > NOW() - INTERVAL '30 days') as archived_last_30_days,
    COUNT(*) FILTER (WHERE deleted_at > NOW() - INTERVAL '90 days') as archived_last_90_days
FROM archived_members;
```

### Find Recently Archived Members
```sql
SELECT 
    email,
    name,
    surname,
    deleted_at,
    deletion_reason
FROM archived_members
ORDER BY deleted_at DESC
LIMIT 10;
```

### Archive Cleanup (Optional)
Consider purging very old archives (e.g., >2 years) if GDPR/compliance requires:
```sql
-- CAUTION: This permanently removes archived data
DELETE FROM archived_members 
WHERE deleted_at < NOW() - INTERVAL '2 years';
```

## Known Limitations
1. **No password recovery**: Deleted members must create new password
2. **No subscription recovery**: New signup requires new payment/subscription
3. **No QR code recovery**: New QR code generated on subscription
4. **Archive persistence**: No automatic cleanup (manual intervention needed)

## Future Enhancements
- [ ] Admin UI to view archived members
- [ ] Restore member from archive (instead of re-signup)
- [ ] Archive retention policy (auto-delete after X years)
- [ ] GDPR compliance tools (export/delete archive on request)
- [ ] Track re-signup events (analytics)

## Related Files
- `lib/services/admin_service.dart` - Admin deletion logic
- `lib/features/admin/members_list_screen.dart` - Admin UI for deletion
- `admin_delete_functions.sql` - Original deletion function (now updated)
- `ADMIN_DELETE_TP_SYSTEM.md` - Trusted Partner deletion (similar pattern)

## Support
If archived member autofill doesn't work:
1. Check `archived_members` table exists and has data
2. Verify RLS policy allows anon SELECT
3. Check browser console for `getArchivedMemberByEmail` logs
4. Verify email match (case-insensitive via `ilike`)
