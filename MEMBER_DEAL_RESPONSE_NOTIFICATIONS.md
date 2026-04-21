# Member Deal Response Notifications

## Overview
This document describes the enhanced push notification system for members when trusted partners approve or reject their deal requests.

## Features
- ✅ Real-time push notifications when TPs respond to deal requests
- ✅ Different messages for POS vs in-app payments
- ✅ Rich notification data with business name and deal details
- ✅ High-priority notifications with sound and vibration
- ✅ Dedicated "Deal Responses" notification channel

## Notification Types

### 1. Deal Approved (In-App Payment)
**Type**: `deal_approved`

**Notification Format**:
```
Title: ✅ Deal Approved - Pay Now
Message: [Business Name] approved your request for [Deal Name]. Tap to pay R[Amount] now.
```

**Example**:
```
Title: ✅ Deal Approved - Pay Now
Message: Woolworths approved your request for 20% Off Fresh Produce. Tap to pay R80.00 now.
```

**Data Payload**:
```dart
{
  'deal_authorization_id': 'uuid',
  'trusted_partner_name': 'Woolworths',
  'business_name': 'Woolworths',
  'deal_name': '20% Off Fresh Produce',
  'amount': 80.0,
  'payment_method': 'in_app',
  'quantity': 1,
}
```

### 2. Deal Approved (POS Payment)
**Type**: `pos_deal_approved`

**Notification Format**:
```
Title: ✅ Deal Approved - Visit Store
Message: [Business Name] approved your request for [Deal Name]. Visit the store to complete payment (R[Amount]).
```

**Example**:
```
Title: ✅ Deal Approved - Visit Store
Message: Pick n Pay approved your request for Buy 2 Get 1 Free (x3). Visit the store to complete payment (R150.00).
```

**Data Payload**:
```dart
{
  'deal_authorization_id': 'uuid',
  'trusted_partner_name': 'Pick n Pay',
  'business_name': 'Pick n Pay',
  'deal_name': 'Buy 2 Get 1 Free',
  'amount': 150.0,
  'payment_method': 'pos',
  'quantity': 3,
}
```

### 3. Deal Rejected
**Type**: `deal_rejected`

**Notification Format**:
```
Title: ❌ Deal Request Declined
Message: [Business Name] declined your request for [Deal Name]. Reason: [Rejection Reason]
```

**Example**:
```
Title: ❌ Deal Request Declined
Message: Spar declined your request for Half Price Bread. Reason: Product out of stock
```

**Data Payload**:
```dart
{
  'deal_authorization_id': 'uuid',
  'trusted_partner_name': 'Spar',
  'business_name': 'Spar',
  'deal_name': 'Half Price Bread',
  'rejection_reason': 'Product out of stock',
}
```

## Implementation Details

### NotificationService Methods

#### `notifyMemberOfDealApproval()`
```dart
Future<void> notifyMemberOfDealApproval({
  required String memberId,
  required String dealAuthorizationId,
  required String trustedPartnerName,
  required String businessName,
  required String dealName,
  required double amount,
  required String paymentMethod,
  int? quantity,
}) async
```

**Behavior**:
- Automatically selects title and message based on payment method
- Includes quantity in message if > 1
- Creates rich notification with business and deal details
- Uses appropriate notification type (deal_approved vs pos_deal_approved)

#### `notifyMemberOfDealRejection()`
```dart
Future<void> notifyMemberOfDealRejection({
  required String memberId,
  required String dealAuthorizationId,
  required String trustedPartnerName,
  required String businessName,
  required String dealName,
  required String rejectionReason,
}) async
```

**Behavior**:
- Includes rejection reason in message
- Creates notification with business and deal context
- Uses 'deal_rejected' type

### DealAuthorizationService Integration

The service automatically fetches business name and deal details when approving/rejecting:

```dart
// In approveDealAuthorization():
final tpResponse = await _supabase
    .from('businesses')
    .select('name')
    .eq('owner_member_id', trustedPartnerId)
    .maybeSingle();

final businessName = tpResponse?['name'] as String? ?? 'Business';

final dealSnapshot = deal.dealSnapshot;
final dealName = dealSnapshot?['name'] as String? ?? 'deal';
final quantity = dealSnapshot?['quantity'] as int?;

await _notificationService.notifyMemberOfDealApproval(
  memberId: deal.memberId,
  dealAuthorizationId: dealId,
  trustedPartnerName: businessName,
  businessName: businessName,
  dealName: dealName,
  amount: deal.amount ?? 0.0,
  paymentMethod: deal.paymentMethod ?? 'pos',
  quantity: quantity,
);
```

### PushNotificationService Channel

**Channel ID**: `deal_responses`

**Configuration**:
```dart
const AndroidNotificationDetails(
  'deal_responses',
  'Deal Responses',
  channelDescription: 'Notifications when businesses approve or reject your deal requests',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
  enableVibration: true,
  playSound: true,
  channelShowBadge: true,
)
```

**Features**:
- High priority for timely delivery
- Sound and vibration enabled
- Badge counter on app icon
- Appears at top of notification shade

## Notification Flow

```
Member requests deal
       ↓
TP approves/rejects in dashboard
       ↓
DealAuthorizationService.approveDealAuthorization() or rejectDealAuthorization()
       ↓
Fetches TP business name from 'businesses' table
       ↓
Extracts deal name and quantity from deal.dealSnapshot
       ↓
NotificationService.notifyMemberOfDealApproval() or notifyMemberOfDealRejection()
       ↓
Creates notification in Supabase with rich data
       ↓
PushNotificationService receives via realtime stream
       ↓
_showLocalNotification() detects type and routes to 'deal_responses' channel
       ↓
Member receives push notification on device
```

## Testing Checklist

- [ ] Member receives approval notification for in-app payment deal
- [ ] Message includes business name and deal name
- [ ] Notification shows "Pay Now" action for in-app payments
- [ ] Member receives approval notification for POS payment deal
- [ ] Message shows "Visit Store" action for POS payments
- [ ] Member receives rejection notification with reason
- [ ] Notifications include quantity when > 1
- [ ] Tapping notification opens app to deal details
- [ ] Sound and vibration work correctly
- [ ] Badge counter increments on app icon

## Database Requirements

### Tables Used
- `notifications` - Stores notification records
- `businesses` - Provides TP business name
- `deal_authorizations` - Contains deal details and member_id

### RLS Policies Required
Members must be able to read their own notifications:
```sql
CREATE POLICY "Users can read own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);
```

## Error Handling

All notification methods include error handling:

```dart
try {
  await _notificationService.notifyMemberOfDealApproval(...);
} catch (e) {
  // Log error but don't block approval flow
  print('Notification failed: $e');
}
```

**Behavior**: Deal approval/rejection proceeds even if notification fails.

## Future Enhancements

- [ ] Add action buttons (Pay Now, View Details)
- [ ] Include deal image in notification
- [ ] Support for batch approvals (multiple deals at once)
- [ ] Configurable notification preferences per member
- [ ] Silent notifications during member's quiet hours
- [ ] Rich media notifications with business logo

## Related Files

- `lib/services/notification_service.dart` - Notification creation logic
- `lib/services/push_notification_service.dart` - Push notification delivery
- `lib/services/deal_authorization_service.dart` - Deal approval/rejection flow
- `lib/models/deal_authorization.dart` - Deal data model
- `ADMIN_PUSH_NOTIFICATIONS_IMPLEMENTATION.md` - Admin notification system
- `TP_DEAL_REQUEST_NOTIFICATIONS.md` - TP notification system
- `PUSH_NOTIFICATION_SYSTEM_SUMMARY.md` - Complete notification architecture
