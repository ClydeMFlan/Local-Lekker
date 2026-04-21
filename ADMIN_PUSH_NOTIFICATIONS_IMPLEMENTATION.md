# Admin Push Notifications Implementation

## Overview
This implementation adds push notifications for admins when trusted partners (TPs) upload banking details or when Paystack subaccounts are created and need approval.

## Features Implemented

### 1. **Admin Notification Service Methods**
Added to `lib/services/notification_service.dart`:

- `notifyAdmins()` - Core method to send notifications to all admin users
- `notifyAdminsOfBankingDetailsUpdate()` - Notify when TP uploads banking details
- `notifyAdminsOfSubaccountApproval()` - Notify when Paystack subaccount needs approval

### 2. **Enhanced Push Notification Channels**
Updated `lib/services/push_notification_service.dart`:

#### New Admin Alert Channel
```dart
Channel ID: 'admin_alerts'
Channel Name: 'Admin Alerts'
Description: 'Critical alerts for administrators requiring immediate attention'
Priority: MAX
Features:
- Vibration enabled
- Sound enabled
- Badge enabled
```

#### Methods Added:
- `showAdminBankingAlert()` - Show push notification for banking details
- `showAdminSubaccountApprovalAlert()` - Show push notification for subaccount approval
- Enhanced `_showLocalNotification()` - Auto-detects notification type and uses appropriate channel

### 3. **Banking Details Upload Notifications**
Updated `lib/features/auth/business_profile_page.dart`:

When a TP saves banking details:
1. **Database notification** created for all admins in `notifications` table
2. **Push notification** sent to admin's device via FCM/local notifications
3. **Notification includes:**
   - Trusted partner name
   - Business name
   - Subaccount code
   - Bank name
   - Timestamp

### 4. **Paystack Subaccount Approval Notifications**
Added trigger in banking details flow:

When Paystack subaccount is successfully created:
1. **Additional notification** sent to admins
2. **Includes:**
   - Subaccount code for Paystack dashboard lookup
   - Account number (masked for security)
   - Bank details
   - Direct link context for verification

## Notification Types

### Type: `banking_details_added`
**Triggered:** When TP uploads/updates banking details
**Title:** 🏦 Banking Details Added
**Message:** "{BusinessName} has added/updated banking details. Verify Paystack subaccount: {SubaccountCode}"
**Data payload:**
```json
{
  "trusted_partner_id": "uuid",
  "trusted_partner_name": "Business Name",
  "business_name": "Business Name",
  "subaccount_code": "ACCT_xxxxx",
  "bank_name": "Capitec Bank"
}
```

### Type: `subaccount_approval_required`
**Triggered:** When Paystack subaccount is successfully created
**Title:** ✅ Subaccount Approval Required
**Message:** "Please approve Paystack subaccount for {BusinessName} on Paystack dashboard"
**Data payload:**
```json
{
  "trusted_partner_id": "uuid",
  "trusted_partner_name": "Business Name",
  "business_name": "Business Name",
  "subaccount_code": "ACCT_xxxxx",
  "bank_name": "Capitec Bank",
  "account_number": "****1234"
}
```

## Admin Dashboard Integration

The admin dashboard already displays these notifications in the "Pending Banking Verifications" section:

Location: `lib/features/admin/admin_dashboard_screen.dart`
- Shows count of pending banking notifications
- Lists all banking detail updates
- Provides "Verify on Paystack" button with direct link
- Shows business name, bank name, subaccount code
- Displays timestamp of upload

## Testing Instructions

### Prerequisites
1. Have at least one admin user in the system
2. Have a trusted partner account
3. Ensure push notifications are enabled on admin device

### Test Scenario 1: Banking Details Upload
1. **Login as Trusted Partner**
2. Navigate to Business Profile page
3. Click "Add/Update Banking Details"
4. Fill in all banking information:
   - Account holder name
   - Bank name (e.g., "Capitec Bank")
   - Account type
   - Account number
   - Branch code
5. Click "Save Banking Details"
6. **Expected Result:**
   - Success message shown to TP
   - Admin receives push notification on device
   - Notification appears in admin notifications list
   - Notification visible in Admin Dashboard under "Pending Banking Verifications"

### Test Scenario 2: Subaccount Creation
1. **Continue from Test Scenario 1**
2. When Paystack subaccount is successfully created:
3. **Expected Result:**
   - Second notification sent to admin
   - Push notification with "Subaccount Approval Required" title
   - Admin can tap notification to view details
   - Notification includes subaccount code

### Test Scenario 3: Admin Notification View
1. **Login as Admin**
2. Navigate to Admin Dashboard
3. **Expected Result:**
   - "Pending Banking Verifications" section shows count badge
   - List displays TP's banking details
   - Shows subaccount code
   - "Verify on Paystack" button available
4. Click notification to mark as read
5. **Expected Result:**
   - Notification marked as read
   - Count badge decrements

### Test Scenario 4: Push Notification Delivery
1. **Ensure admin app is in background**
2. Have TP upload banking details (as in Test Scenario 1)
3. **Expected Result:**
   - Push notification appears in Android notification tray
   - Notification uses "Admin Alerts" channel
   - High priority notification (appears at top)
   - Vibration and sound triggered
   - Badge appears on app icon

## Database Schema

### Notifications Table
Notifications are stored in the `notifications` table with the following structure:
```sql
{
  id: uuid,
  user_id: uuid,  -- Admin user ID
  title: text,
  message: text,
  type: text,  -- 'banking_details_added' or 'subaccount_approval_required'
  data: jsonb,  -- Contains TP details and subaccount info
  is_read: boolean,
  created_at: timestamp
}
```

### RLS Policies
- Admins can view all notifications sent to them
- Any authenticated user can create notifications (required for TP → Admin flow)
- Users can only update their own notifications (mark as read)

## Security Considerations

1. **Account Number Masking:**
   - Full account numbers never stored in notifications
   - Only last 4 digits shown: `****1234`
   - Full account number stored securely in `trusted_partner_bank_accounts` table

2. **Admin-Only Access:**
   - Notifications only created for users with `role = 'admin'` in profiles table
   - RLS policies ensure admins only see their own notifications

3. **Subaccount Verification:**
   - Admin receives code to verify on Paystack dashboard
   - No sensitive banking details exposed in push notification text
   - Full details available only in-app after authentication

## Future Enhancements

1. **Rich Push Notifications:**
   - Add deep linking to specific TP profile
   - Include quick actions (Approve/Reject)
   - Add images (business logo)

2. **Email Notifications:**
   - Send email to admin when banking details uploaded
   - Include direct link to admin dashboard

3. **Batch Notifications:**
   - Group multiple banking updates into digest
   - Send summary at specific times

4. **Notification Preferences:**
   - Allow admins to configure notification types
   - Set quiet hours
   - Choose notification channels (push, email, SMS)

## Troubleshooting

### Notifications Not Received
1. Check admin user has `role = 'admin'` in profiles table
2. Verify `notifications` table has new entries
3. Check push notification permissions on device
4. Ensure app is in foreground or background (not force-closed)
5. Check Android notification channel is not muted

### Database Errors
1. Verify RLS policies allow cross-user notification creation
2. Check `notifications` table has proper indexes
3. Ensure foreign key constraints are satisfied

### Paystack Subaccount Not Created
1. Check TP has valid banking details
2. Verify Paystack API key is configured
3. Check network connectivity
4. Review PaystackService logs for errors

## Code Locations

| Feature | File Path |
|---------|-----------|
| Notification service methods | `lib/services/notification_service.dart` |
| Push notification channels | `lib/services/push_notification_service.dart` |
| Banking details upload | `lib/features/auth/business_profile_page.dart` |
| Admin dashboard display | `lib/features/admin/admin_dashboard_screen.dart` |
| Notification model | `lib/models/notification.dart` |

## API Reference

### NotificationService Methods

```dart
// Notify all admins with a message
Future<void> notifyAdmins({
  required String title,
  required String message,
  required String type,
  Map<String, dynamic>? data,
})

// Notify admins when TP uploads banking details
Future<void> notifyAdminsOfBankingDetailsUpdate({
  required String trustedPartnerId,
  required String trustedPartnerName,
  required String businessName,
  required String subaccountCode,
  required String bankName,
})

// Notify admins when Paystack subaccount needs approval
Future<void> notifyAdminsOfSubaccountApproval({
  required String trustedPartnerId,
  required String trustedPartnerName,
  required String businessName,
  required String subaccountCode,
  required String bankName,
  required String accountNumber,
})
```

### PushNotificationService Methods

```dart
// Show admin alert for banking details
Future<void> showAdminBankingAlert({
  required String title,
  required String message,
  required String notificationId,
})

// Show admin alert for subaccount approval
Future<void> showAdminSubaccountApprovalAlert({
  required String title,
  required String message,
  required String notificationId,
})
```

## Support

For issues or questions:
1. Check logs in admin dashboard
2. Review notification table entries in Supabase
3. Verify Paystack subaccount creation in Paystack dashboard
4. Test with sandbox/development environment first
