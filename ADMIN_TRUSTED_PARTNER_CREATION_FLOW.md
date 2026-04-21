# Admin-Created Trusted Partner Flow

## Overview
When an admin creates a trusted partner account, the system now follows the same logic as a normal trusted partner signup, except the password is created by the trusted partner on their first sign-in.

## Complete Flow

### 1. Admin Creates Trusted Partner
**File:** `lib/features/admin/admin_add_trusted_partner_page.dart`

When an admin creates a trusted partner:
- User is created in `auth.users` with a temporary password
- All user data is stored in `userMetadata`:
  - `admin_created: true`
  - `password_set: false`
  - `user_type: 'trusted_partner'`
  - Personal info (name, surname, email, etc.)
  - Business name

### 2. Database Trigger Creates Profile
**File:** `supabase/migrations/20251202000001_update_trigger_for_trusted_partner.sql`

The `handle_new_user_role_assignment()` trigger automatically:
- Creates a complete profile in `profiles` table with all metadata
- Sets `admin_created: true` and `password_set: false`
- Creates a membership record with role `trusted_partner`
- Creates a `trusted_partners` record with the business name

### 3. Trusted Partner First Sign-In
**File:** `lib/features/auth/welcome_page.dart` (lines 484-521)

When the trusted partner signs in for the first time:
- App checks `admin_created` and `password_set` status
- If `admin_created: true` AND `password_set: false`:
  - Redirects to `SetInitialPasswordPage`

### 4. Set Password
**File:** `lib/features/auth/set_initial_password_page.dart`

The trusted partner:
- Creates their own password
- System updates `auth.users` password
- System updates `profiles.password_set: true`
- Sends OTP for email verification
- After OTP verification, redirects to `BusinessProfilePage`

### 5. Complete Business Profile
**File:** `lib/features/auth/business_profile_page.dart`

The trusted partner completes their business profile:
- Business details (category, address, contact info)
- Logo upload (optional)
- System creates/updates `businesses` record
- Redirects to trusted partner home page

## Database Schema Changes

### New Columns in `profiles` Table
**Migration:** `supabase/migrations/20251202000000_add_admin_created_password_set_columns.sql`

```sql
ALTER TABLE public.profiles ADD COLUMN admin_created BOOLEAN DEFAULT false;
ALTER TABLE public.profiles ADD COLUMN password_set BOOLEAN DEFAULT true;
```

### Updated Trigger Function
**Migration:** `supabase/migrations/20251202000001_update_trigger_for_trusted_partner.sql`

The trigger now:
- Handles `user_type: 'trusted_partner'`
- Creates `trusted_partners` records automatically
- Tracks `admin_created` and `password_set` from metadata

## Key Files Modified

1. **`lib/features/admin/admin_add_trusted_partner_page.dart`**
   - Removed manual profile creation
   - All data now passed via `userMetadata`
   - Changed `insert` to `upsert` for idempotency

2. **`supabase/migrations/20250919170000_create_automatic_role_assignment_trigger.sql`**
   - Added support for `trusted_partner` user type
   - Added `admin_created` and `password_set` tracking

3. **`supabase/migrations/20251202000000_add_admin_created_password_set_columns.sql`**
   - New migration to add required columns

4. **`supabase/migrations/20251202000001_update_trigger_for_trusted_partner.sql`**
   - Updated trigger to handle trusted partners

## Testing Checklist

- [ ] Admin can create trusted partner account
- [ ] Profile is created automatically in `profiles` table
- [ ] `trusted_partners` record is created with business name
- [ ] `memberships` record is created with role `trusted_partner`
- [ ] Trusted partner receives temporary password
- [ ] On first sign-in, trusted partner is redirected to password setup
- [ ] After setting password, `password_set` is updated to `true`
- [ ] OTP verification works correctly
- [ ] After OTP, trusted partner is redirected to business profile page
- [ ] Business profile completion works correctly
- [ ] After completion, trusted partner is redirected to home page

## Benefits

1. **Consistency:** Admin-created accounts follow the same flow as self-signup
2. **Security:** Trusted partners set their own passwords
3. **Automation:** Database trigger handles all record creation
4. **Idempotency:** Using `upsert` prevents duplicate key errors
5. **Tracking:** `admin_created` and `password_set` flags enable proper routing
