# Account Deactivation Feature Implementation

## Overview
Complete implementation of account deactivation functionality for both **Trusted Partners** and **Members** in the Local Lekker app, with admin visibility and reactivation capabilities.

## Features Implemented

### 1. Deactivation Confirmation Screen
**File:** `lib/features/auth/deactivation_confirmation_page.dart`

- Beautiful UI with warning card explaining the consequences
- Dropdown list of predefined deactivation reasons:
  - No longer using the service
  - Switching to a different service
  - Too expensive
  - Not satisfied with the service
  - Business/partnership ended
  - Personal reasons
  - Other (with text input field)
- Confirmation checkbox to prevent accidental deactivations
- Loading state with spinner button
- Error handling with snackbar feedback

### 2. Admin Service Methods
**File:** `lib/services/admin_service.dart`

#### New Methods Added:

**`deactivateTrustedPartner(String tpUserId, {String reason})`**
- Sets `is_deactivated` flag to true in profiles table
- Marks all trusted partner discounts as inactive
- Updates trusted_partners table with deactivation flag
- Returns deactivation details

**`deactivateMember(String memberId, {String reason})`**
- Sets `is_deactivated` flag to true in profiles table
- Updates subscription status to 'deactivated'
- Deactivates all active QR codes for the member
- Returns deactivation details including Paystack subscription code

**`getDeactivatedTrustedPartners()`**
- Fetches all deactivated trusted partners from profiles table
- Orders by deactivation date (most recent first)

**`getDeactivatedMembers()`**
- Fetches all deactivated members from profiles table
- Orders by deactivation date (most recent first)

**`reactivateTrustedPartner(String tpUserId)`**
- Clears deactivation flags in both profiles and trusted_partners tables
- Restores visibility to members

**`reactivateMember(String memberId)`**
- Clears deactivation flags in profiles table
- Allows member to restore subscription

### 3. Trusted Partner (Business) Profile
**File:** `lib/features/auth/business_profile_page.dart`

**Changes:**
- Added import for `AdminService` and `DeactivationConfirmationPage`
- Added "Deactivate Business" section in profile form
- Red-themed card with warning icon showing consequences
- "Deactivate Business" button that opens deactivation flow
- Calls `_deactivateBusinessAccount()` with deactivation reason
- Navigates to home on successful deactivation

**User Flow:**
1. TP clicks "Deactivate Business" button
2. Deactivation confirmation screen opens
3. TP selects reason and confirms
4. Business account deactivated in database
5. All discounts hidden from members
6. Redirected to home page

### 4. Member Profile
**File:** `lib/features/auth/member_profile_page.dart`

**Changes:**
- Added imports for `AdminService` and `DeactivationConfirmationPage`
- Added "Deactivate Account" section in profile form
- Red-themed card with warning icon showing consequences
- "Deactivate Account" button that opens deactivation flow
- Calls `_deactivateMemberAccount()` with deactivation reason
- Navigates to home on successful deactivation

**User Flow:**
1. Member clicks "Deactivate Account" button
2. Deactivation confirmation screen opens
3. Member selects reason and confirms
4. Member account deactivated in database
5. Subscription marked as deactivated
6. All QR codes deactivated
7. Redirected to home page

### 5. Admin - Trusted Partners View
**File:** `lib/features/admin/trusted_partners_list_screen.dart`

**Changes:**
- Added `deactivatedPartners` list
- Changed TabController from 2 to 3 tabs
- Added new "Deactivated" tab with red badge
- Calls `_loadDeactivatedPartners()` to fetch deactivated TPs
- New `_buildDeactivatedPartnersList()` widget displays deactivated partners
- Each deactivated partner card shows:
  - Blocked icon with red background
  - Business name
  - Full name
  - Email address
  - Options menu: Reactivate, View Details
- `_reactivateTrustedPartner()` method to restore deactivated businesses

**Features:**
- Deactivated partners visible in separate tab
- Quick access to reactivate with confirmation
- View profile details for deactivated partners
- Real-time update of tab count

### 6. Admin - Members View
**File:** `lib/features/admin/members_list_screen.dart`

**Changes:**
- Added `deactivatedMembers` list
- Changed TabController from 3 to 4 tabs
- Added new "Deactivated" tab with red badge
- Added `_loadDeactivatedMembers()` to fetch deactivated members
- New `_buildDeactivatedMembersList()` widget displays deactivated members
- Each deactivated member card shows:
  - Blocked icon with red background
  - Full name
  - Email address
  - "Deactivated" status label
  - Options menu: Reactivate, View Details
- `_reactivateMember()` method to restore deactivated accounts

**Features:**
- Deactivated members visible in separate tab
- Quick access to reactivate with confirmation
- View member details for deactivated accounts
- Real-time update of tab count

## Database Operations

The implementation expects the following columns in the `profiles` table:
- `is_deactivated` (BOOLEAN) - Marks account as deactivated
- `deactivation_reason` (TEXT) - Stores the reason provided by user
- `deactivated_at` (TIMESTAMP) - Records when deactivation occurred

For members, the implementation also updates:
- `subscriptions.status` = 'deactivated'
- `user_qr_codes.is_active` = false (for all active codes)

## User Experience Flow

### Trusted Partner Deactivation
```
Business Profile Page
  ↓
Click "Deactivate Business" button
  ↓
Deactivation Confirmation Screen
  - Shows 3 consequences
  - Select reason from dropdown
  - Check confirmation box
  ↓
Click "Deactivate" button
  ↓
AdminService.deactivateTrustedPartner()
  - Database updates
  - Discounts hidden from members
  ↓
Success message
  ↓
Redirect to Home
```

### Member Deactivation
```
Member Profile Page
  ↓
Click "Deactivate Account" button
  ↓
Deactivation Confirmation Screen
  - Shows 4 consequences
  - Select reason from dropdown
  - Check confirmation box
  ↓
Click "Deactivate" button
  ↓
AdminService.deactivateMember()
  - Database updates
  - Subscription marked deactivated
  - QR codes disabled
  ↓
Success message
  ↓
Redirect to Home
```

### Admin Reactivation
```
Admin Dashboard → Members/Trusted Partners
  ↓
Click "Deactivated" tab
  ↓
See list of deactivated accounts
  ↓
Click menu → "Reactivate"
  ↓
AdminService.reactivate*()
  - Clears deactivation flags
  - Restores visibility
  ↓
Success message
  ↓
Lists update automatically
```

## Key Features

### Security
✅ Confirmation screen with understanding checkbox
✅ Warning dialogs with clear consequences
✅ Admin-only reactivation capability
✅ Reason logging for deactivations

### User Experience
✅ Clear visual feedback (red color scheme)
✅ Explicit warnings about consequences
✅ Separate admin view for deactivated accounts
✅ Quick reactivation from admin panel

### Data Integrity
✅ Paystack subscription tracking (for members)
✅ QR code deactivation cascade
✅ Discount visibility removal
✅ Timestamps for audit trail

### Performance
✅ Separate loading of deactivated accounts
✅ Efficient database queries
✅ Tab-based organization for admin view
✅ Real-time badge count updates

## Future Enhancements

1. **Grace Period:** Add 7-14 day grace period before complete deactivation
2. **Reactivation Restrictions:** Limit reactivation attempts after deactivation
3. **Audit Reports:** Track deactivations and reactivations with IP/device info
4. **Notification:** Send email confirmations for deactivations
5. **Payment Webhook Integration:** Handle Paystack subscription cancellation directly
6. **Export Data:** Allow users to request data export before deactivation

## Testing Checklist

- [ ] TP can deactivate business account
- [ ] Member can deactivate account
- [ ] Deactivation confirmation screen works correctly
- [ ] Reason selection and validation works
- [ ] Admin sees deactivated TPs in new tab
- [ ] Admin sees deactivated members in new tab
- [ ] Admin can reactivate deactivated accounts
- [ ] Deactivated accounts removed from active lists
- [ ] Tab counts update correctly
- [ ] Database flags set correctly
- [ ] QR codes disabled for deactivated members
- [ ] Discounts hidden for deactivated TPs
- [ ] Error handling works for failures
- [ ] Loading states display correctly

## Files Modified

1. ✅ `lib/features/auth/deactivation_confirmation_page.dart` (NEW)
2. ✅ `lib/services/admin_service.dart` (MODIFIED)
3. ✅ `lib/features/auth/business_profile_page.dart` (MODIFIED)
4. ✅ `lib/features/auth/member_profile_page.dart` (MODIFIED)
5. ✅ `lib/features/admin/trusted_partners_list_screen.dart` (MODIFIED)
6. ✅ `lib/features/admin/members_list_screen.dart` (MODIFIED)

All files pass Dart analysis with no errors.
