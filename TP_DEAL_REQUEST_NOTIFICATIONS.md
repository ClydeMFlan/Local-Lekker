# Trusted Partner Push Notifications - Deal Requests

## Overview
This implementation adds real-time push notifications for trusted partners (TPs) when members request deals. TPs receive instant alerts on their devices with deal details, member information, and payment method.

## Features Implemented

### 1. **Enhanced Deal Request Notification**
Updated `lib/services/notification_service.dart`:

#### New Method: `notifyTrustedPartnerOfDealRequest()`
Sends a rich notification to TP when a member requests a deal.

**Parameters:**
- `trustedPartnerId` - TP user ID
- `dealAuthorizationId` - Deal authorization record ID
- `memberId` - Member who requested the deal
- `memberName` - Member's full name
- `dealName` - Name of the deal
- `amount` - Total amount (including quantity)
- `paymentMethod` - "pos" (in-store) or "in_app"
- `quantity` - Number of items (optional)

**Example Usage:**
```dart
await NotificationService().notifyTrustedPartnerOfDealRequest(
  trustedPartnerId: 'tp-uuid-123',
  dealAuthorizationId: 'auth-uuid-456',
  memberId: 'member-uuid-789',
  memberName: 'John Doe',
  dealName: '20% off Coffee',
  amount: 45.00,
  paymentMethod: 'in_app',
  quantity: 2,
);
```

### 2. **Updated Deal Authorization Service**
Modified `lib/services/deal_authorization_service.dart`:

**Changes:**
- Imports `NotificationService`
- Fetches member's full name from profiles
- Uses enhanced notification method instead of basic `createNotification()`
- Includes member name and deal details in notification

**Before:**
```dart
await _discountService.createNotification(
  userId: trustedPartnerUserId,
  title: 'New Deal Authorization Request',
  message: 'A member has requested authorization for a deal worth R${amount.toStringAsFixed(2)}',
  type: 'deal_request',
  data: {...},
);
```

**After:**
```dart
await _notificationService.notifyTrustedPartnerOfDealRequest(
  trustedPartnerId: trustedPartnerUserId,
  dealAuthorizationId: dealAuth.id,
  memberId: memberId,
  memberName: 'John Doe',
  dealName: '20% off Coffee',
  amount: amount,
  paymentMethod: paymentMethod,
  quantity: quantity,
);
```

### 3. **Enhanced Push Notification Channel**
Updated `lib/services/push_notification_service.dart`:

#### Deal Requests Notification Channel
```dart
Channel ID: 'deal_requests'
Channel Name: 'Deal Requests'
Description: 'Notifications when members request deals from your business'
Priority: HIGH
Features:
- Vibration enabled ✅
- Sound enabled ✅
- Badge enabled ✅
- High importance ✅
```

**Auto-Detection:**
The `_showLocalNotification()` method now automatically detects `deal_request` type notifications and applies the appropriate channel settings.

## Notification Flow

```
1. Member opens Local Lekker app
2. Member browses deals from a TP
3. Member selects deal and clicks "Request Deal"
4. Member fills in quantity, payment method, notes
5. Member submits request
6. System creates deal_authorization record
7. System fetches member's name from profiles
8. 📱 PUSH NOTIFICATION sent to TP's device
9. TP receives notification with:
   - Member name
   - Deal name
   - Amount (with quantity if > 1)
   - Payment method (In-Store or In-App)
10. TP can tap notification to view deal authorization
11. TP approves or rejects the deal
```

## Notification Format

### Title
```
🛒 New Deal Request
```

### Message Examples

**Single Item, In-App Payment:**
```
John Doe requested: 20% off Coffee - R45.00 (In-App)
```

**Multiple Items, In-Store Payment:**
```
Jane Smith requested: Buy 1 Get 1 Pizza (x2) - R180.00 (In-Store)
```

**Custom Price Deal:**
```
Mike Johnson requested: Weight-based Discount - R125.50 (In-App)
```

### Data Payload
```json
{
  "deal_authorization_id": "auth-uuid-456",
  "member_id": "member-uuid-789",
  "member_name": "John Doe",
  "deal_name": "20% off Coffee",
  "amount": 45.00,
  "payment_method": "in_app",
  "quantity": 2
}
```

## Integration Points

### 1. Deal Authorization Request Page
**File:** `lib/features/auth/deal_authorization_request_page.dart`

When member submits deal request, the page calls:
```dart
await _dealService.requestDealAuthorization(
  memberId: user.id,
  discountId: discount.id,
  paymentMethod: _selectedPaymentMethod,
  amount: amount,
  quantity: _quantity,
  // ... other params
);
```

This triggers the notification flow automatically.

### 2. TP Dashboard
**File:** `lib/features/business/trusted_partner_home_page.dart`

TPs can view pending deal requests in their dashboard. The notification badge updates in real-time when new requests arrive.

### 3. Deal Approval Popup
**File:** `lib/services/deal_approval_popup_service.dart`

When TP receives notification and has the app open, a popup appears showing:
- Member name
- Deal details
- Amount
- Quick approve/reject buttons

## Testing Instructions

### Test Scenario 1: Basic Deal Request (In-App Payment)

1. **Setup:**
   - Have a TP account with active deals
   - Have a member account
   - Ensure TP device has push notifications enabled

2. **Steps:**
   - Login as **Member**
   - Navigate to Deals page
   - Find a deal from the TP
   - Click "Request Deal"
   - Select payment method: **In-App**
   - Set quantity: **1**
   - Click "Submit Request"

3. **Expected Result:**
   - Member sees success message
   - TP device receives push notification:
     - Title: "🛒 New Deal Request"
     - Message: "{Member Name} requested: {Deal Name} - R{Amount} (In-App)"
   - Notification appears in TP's notification list
   - Badge count increments on TP dashboard

### Test Scenario 2: Multiple Items (In-Store Payment)

1. **Steps:**
   - Login as **Member**
   - Request a deal with:
     - Quantity: **3**
     - Payment method: **In-Store (POS)**
   - Submit request

2. **Expected Result:**
   - TP receives notification with:
     - Message includes "(x3)" for quantity
     - Payment method shows "(In-Store)"
   - Total amount reflects quantity × unit price

### Test Scenario 3: Background Notification

1. **Setup:**
   - TP app in background or closed
   - Member submits deal request

2. **Expected Result:**
   - Push notification appears in Android notification tray
   - Sound plays
   - Device vibrates
   - Badge appears on app icon
   - Tapping notification opens app to deal details

### Test Scenario 4: Multiple Requests

1. **Steps:**
   - Have 3 different members request deals from same TP
   - Each request within 1 minute

2. **Expected Result:**
   - TP receives 3 separate push notifications
   - Each notification shows different member name
   - All 3 appear in notification list
   - Badge shows "3" pending requests

## Database Schema

### Notifications Table
```sql
{
  id: uuid,
  user_id: uuid,  -- TP user ID
  title: text,  -- "🛒 New Deal Request"
  message: text,  -- "{Member} requested: {Deal} - R{Amount}"
  type: text,  -- "deal_request"
  data: jsonb,  -- Deal details
  is_read: boolean,
  created_at: timestamp
}
```

### Example Record
```json
{
  "id": "notif-uuid-123",
  "user_id": "tp-uuid-456",
  "title": "🛒 New Deal Request",
  "message": "John Doe requested: 20% off Coffee (x2) - R90.00 (In-App)",
  "type": "deal_request",
  "data": {
    "deal_authorization_id": "auth-uuid-789",
    "member_id": "member-uuid-012",
    "member_name": "John Doe",
    "deal_name": "20% off Coffee",
    "amount": 90.00,
    "payment_method": "in_app",
    "quantity": 2
  },
  "is_read": false,
  "created_at": "2026-01-18T14:30:00Z"
}
```

## Notification Channels Summary

| Channel ID | Name | Priority | Use Case | Features |
|------------|------|----------|----------|----------|
| `admin_alerts` | Admin Alerts | MAX | Admin banking/subaccount alerts | Vibration, Sound, Badge |
| `deal_requests` | Deal Requests | HIGH | TP deal request notifications | Vibration, Sound, Badge |
| `deal_notifications` | Deal Notifications | HIGH | General deal updates | Basic |

## Security & Privacy

1. **Member Name Privacy:**
   - Full name shown to TP (authorized business partner)
   - Member ID included for audit trail
   - No sensitive member data exposed

2. **Payment Method Visibility:**
   - TP sees payment method to prepare accordingly
   - In-Store: TP expects member to visit location
   - In-App: TP knows payment will be processed online

3. **Amount Transparency:**
   - TP sees exact amount member will pay
   - Helps TP verify pricing is correct
   - Prevents pricing disputes

4. **RLS Policies:**
   - TP can only view their own deal request notifications
   - Member data access controlled by existing policies
   - Notifications auto-created with proper permissions

## Troubleshooting

### "No notification received"
✅ **Check:** TP has notifications enabled in app settings
✅ **Check:** Device notification permissions granted
✅ **Check:** "Deal Requests" channel not muted in Android settings
✅ **Check:** TP user ID matches deal's trusted_partner_id

### "Notification shows 'A member' instead of name"
✅ **Check:** Member has `full_name` or `name` + `surname` in profiles table
✅ **Check:** Member ID exists in profiles table
✅ **Run:** Update member profile to include name fields

### "Notification received but no details"
✅ **Check:** Deal authorization created successfully
✅ **Check:** Notification `data` field contains all required keys
✅ **Check:** SupabaseService connection active
✅ **Check:** Realtime notifications stream active

### "Badge count not updating"
✅ **Check:** PushNotificationService initialized in main.dart
✅ **Check:** `onNotificationsChanged` callback set
✅ **Check:** TP dashboard listening to notification changes
✅ **Restart:** App to refresh notification subscription

## Performance Considerations

1. **Member Name Lookup:**
   - Single query to profiles table
   - Cached in notification data
   - No repeated lookups needed

2. **Real-time Delivery:**
   - Supabase realtime triggers immediately
   - Local notification shown within 1-2 seconds
   - No polling or delays

3. **Notification Storage:**
   - All notifications stored in database
   - Can be retrieved if push fails
   - History available for audit

## Future Enhancements

1. **Quick Actions:**
   - "Approve" button directly in notification
   - "Reject" button with reason selection
   - "View Details" deep link

2. **Rich Notifications:**
   - Show deal image in notification
   - Display member profile picture
   - Include business logo

3. **Notification Grouping:**
   - Group multiple requests from same member
   - Collapse notifications older than 24h
   - Summary notification for 10+ requests

4. **Custom Sounds:**
   - Different sound for high-value deals
   - Urgent sound for in-store requests
   - Customizable per TP preference

5. **Analytics:**
   - Track notification delivery rate
   - Measure time from request to approval
   - Monitor notification engagement

## Code Locations

| Feature | File Path |
|---------|-----------|
| TP notification helper | `lib/services/notification_service.dart` |
| Deal authorization service | `lib/services/deal_authorization_service.dart` |
| Push notification channels | `lib/services/push_notification_service.dart` |
| Deal request page | `lib/features/auth/deal_authorization_request_page.dart` |
| TP dashboard | `lib/features/business/trusted_partner_home_page.dart` |
| Deal approval popup | `lib/services/deal_approval_popup_service.dart` |

## Summary

✅ **Push notifications implemented** for TP deal requests
✅ **Member name included** in notification message
✅ **Payment method displayed** (In-Store or In-App)
✅ **Quantity shown** when more than 1 item
✅ **High priority channel** with sound and vibration
✅ **Real-time delivery** via Supabase
✅ **Full data payload** for deep linking
✅ **Backward compatible** with existing notification system

**Trusted partners now receive instant push notifications when members request deals, with all relevant details to make quick approve/reject decisions!** 🎉
