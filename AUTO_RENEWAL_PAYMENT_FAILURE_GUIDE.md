# Automatic Subscription Renewal & Payment Failure Handling

## Overview
Local Lekker now supports **fully automatic monthly subscription renewals** via Paystack. When a member's subscription expires, Paystack automatically attempts to charge their saved card. The system handles both successful renewals and payment failures gracefully.

## How It Works

### 🔄 Successful Auto-Renewal Flow

1. **30 days after initial payment** → Paystack automatically charges member's card
2. **Webhook fires** → `subscription.charge` event received by edge function
3. **Subscription extended** → `expires_at` and `current_period_end` updated by +30 days
4. **Profile reactivated** → `profiles.subscription` set to `'active'`
5. **QR code activated** → User can immediately use their QR code
6. **Notification sent** → User receives in-app notification confirming renewal
7. **Payment recorded** → Entry created in `payments` table for tracking

### ❌ Payment Failure Flow

1. **Payment fails** → Paystack sends `invoice.payment_failed` webhook
2. **Subscription status updated** → Set to `'payment_failed'`
3. **Profile deactivated** → `profiles.subscription` set to `'payment_failed'`
4. **QR codes deactivated** → All active QR codes for user are disabled
5. **Notification sent** → User receives in-app alert about payment failure
6. **Action required** → User must update payment method to reactivate

### 🔔 User Notifications

Notifications are created in the `notifications` table with these types:

#### Subscription Renewal
```json
{
  "type": "subscription_renewal",
  "title": "Subscription Renewed",
  "message": "Your Local Lekker subscription has been automatically renewed until [DATE]. Thank you for being a valued member!",
  "data": {
    "renewed_at": "2026-01-05T10:00:00Z",
    "expires_at": "2026-02-04T10:00:00Z",
    "amount": 99.00,
    "payment_reference": "trx_abc123"
  }
}
```

#### Payment Failure
```json
{
  "type": "payment_failure",
  "title": "Payment Failed",
  "message": "Your subscription payment could not be processed. Please update your payment method to continue enjoying Local Lekker benefits.",
  "data": {
    "subscription_code": "SUB_xyz789",
    "failed_at": "2026-01-05T10:00:00Z",
    "action_required": "update_payment_method"
  }
}
```

## Implementation Details

### Webhook Handler (Supabase Edge Function)

**Location:** `supabase/functions/paystack-webhook/index.ts`

**Key Events:**
- `subscription.charge` - Handles auto-renewal charges
- `invoice.payment_failed` - Handles payment failures
- `subscription.create` - Initial subscription setup
- `subscription.disable` - User cancellation

**Database Updates on Renewal:**
```typescript
// Update subscription
await supabase.from('subscriptions').update({
  expires_at: newExpiryDate,
  current_period_end: newExpiryDate,
  status: 'active',
  paystack_subscription_code: subscriptionCode,
  updated_at: new Date().toISOString()
})

// Reactivate profile
await supabase.from('profiles').update({
  subscription: 'active',
  updated_at: new Date().toISOString()
})
```

**Database Updates on Payment Failure:**
```typescript
// Update subscription status
await supabase.from('subscriptions').update({
  status: 'payment_failed',
  updated_at: new Date().toISOString()
})

// Deactivate profile
await supabase.from('profiles').update({
  subscription: 'payment_failed',
  updated_at: new Date().toISOString()
})

// Deactivate QR codes
await supabase.from('user_qr_codes').update({
  is_active: false,
  updated_at: new Date().toISOString()
})
```

### Notification Service

**Location:** `lib/services/notification_service.dart`

**New Methods:**
- `hasPaymentFailureNotification(userId)` - Check if user has unread payment failure
- `getPaymentNotifications(userId)` - Get all payment-related notifications
- `getLatestPaymentFailure(userId)` - Get most recent payment failure notification

### UI Components

**Location:** `lib/features/payments/payment_failure_alert.dart`

**Widgets:**
1. `PaymentFailureAlert` - Full alert card with "Update Payment Method" button
2. `PaymentFailureBanner` - Compact banner for top of pages

**Usage Example:**
```dart
// In MembersHomePage or any page
PaymentFailureAlert(
  userId: currentUser.id,
  onUpdatePaymentMethod: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          selectedPlan: 'monthly',
          planDetails: {...},
        ),
      ),
    );
  },
)
```

## Subscription Status States

| Status | Meaning | Profile Active | QR Active | Action Required |
|--------|---------|----------------|-----------|-----------------|
| `active` | Subscription valid | ✅ Yes | ✅ Yes | None |
| `expired` | Period ended, no auto-renew | ❌ No | ❌ No | Manual renewal |
| `payment_failed` | Auto-renewal failed | ❌ No | ❌ No | Update payment method |
| `cancelled` | User cancelled | ❌ No | ❌ No | Resubscribe |
| `pending` | Initial signup incomplete | ❌ No | ❌ No | Complete payment |

## Testing

### Test Auto-Renewal

1. **Create test subscription** with 1-minute interval plan (only in Paystack Test Mode)
2. **Wait 1 minute** for auto-charge
3. **Check webhook logs:**
   ```bash
   supabase functions logs paystack-webhook --tail
   ```
4. **Verify database:**
   ```sql
   SELECT 
     expires_at,
     current_period_end,
     status,
     updated_at
   FROM subscriptions
   WHERE user_id = 'YOUR_USER_ID';
   ```

### Test Payment Failure

1. **Simulate failure** using Paystack Test Mode
2. **Send test webhook:**
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -H "x-paystack-signature: test_signature" \
     -d '{
       "event": "invoice.payment_failed",
       "data": {
         "subscription_code": "SUB_test123",
         "customer": {
           "email": "test@example.com"
         }
       }
     }'
   ```
3. **Check notification created:**
   ```sql
   SELECT * FROM notifications
   WHERE user_id = 'YOUR_USER_ID'
   AND type = 'payment_failure'
   ORDER BY created_at DESC
   LIMIT 1;
   ```

### Test UI Alert

1. **Create test payment failure notification**
2. **Open app** with affected user
3. **Verify alert displays** with red warning
4. **Click "Update Payment Method"** → Should navigate to payment screen
5. **Click "Dismiss"** → Alert should disappear

## Deployment Checklist

- [ ] Deploy webhook function:
  ```bash
  supabase functions deploy paystack-webhook --no-verify-jwt
  ```
- [ ] Verify webhook URL in Paystack Dashboard
- [ ] Confirm events enabled:
  - ✅ `subscription.charge`
  - ✅ `invoice.payment_failed`
  - ✅ `subscription.create`
  - ✅ `subscription.disable`
- [ ] Test with Paystack Test Mode first
- [ ] Monitor first real renewal (30 days after launch)
- [ ] Set up alerts for webhook failures

## Monitoring & Alerts

### Check Renewal Health
```sql
-- Recently renewed subscriptions
SELECT 
  p.email,
  s.expires_at,
  s.status,
  s.updated_at
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active'
  AND s.updated_at > NOW() - INTERVAL '7 days'
ORDER BY s.updated_at DESC;
```

### Check Payment Failures
```sql
-- Recent payment failures
SELECT 
  p.email,
  s.status,
  s.paystack_subscription_code,
  s.updated_at
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'payment_failed'
ORDER BY s.updated_at DESC;
```

### Check Notifications Sent
```sql
-- Recent payment notifications
SELECT 
  p.email,
  n.type,
  n.title,
  n.is_read,
  n.created_at
FROM notifications n
JOIN profiles p ON n.user_id = p.id
WHERE n.type IN ('payment_failure', 'subscription_renewal')
  AND n.created_at > NOW() - INTERVAL '7 days'
ORDER BY n.created_at DESC;
```

## Troubleshooting

### Renewal Not Working
1. ✅ Check Paystack subscription status (should be "active")
2. ✅ Verify webhook delivered in Paystack Dashboard
3. ✅ Check edge function logs for errors
4. ✅ Confirm `paystack_subscription_code` matches in database

### Notifications Not Appearing
1. ✅ Check `notifications` table for entry
2. ✅ Verify RLS policies allow user to read
3. ✅ Confirm `is_read` is `false`
4. ✅ Check app is calling `NotificationService.getLatestPaymentFailure()`

### Profile Not Reactivating
1. ✅ Verify webhook processed successfully
2. ✅ Check `profiles.subscription` field updated to 'active'
3. ✅ Confirm QR codes reactivated (`is_active = true`)
4. ✅ Review edge function logs for database errors

## Cost Analysis

**Paystack Fees:** 1.5% + R2 per transaction

**Monthly Subscription (R99):**
- Fee per transaction: R99 × 1.5% + R2 = **R3.49**
- Net revenue: R99 - R3.49 = **R95.51 per member**

**Annual Revenue (1000 members):**
- Gross: R99,000 × 12 = R1,188,000
- Paystack fees: R3,490 × 12 = R41,880
- Net: **R1,146,120**

## Support Resources

- **Paystack Docs:** https://paystack.com/docs/payments/subscriptions/
- **Webhook Reference:** https://paystack.com/docs/payments/webhooks/
- **Supabase Edge Functions:** https://supabase.com/docs/guides/functions
- **Notification System:** See `NOTIFICATION_SYSTEM.md` (if exists)

## Next Steps

1. ✅ Monitor first batch of renewals (30 days after launch)
2. ✅ Analyze payment failure rate
3. ✅ Add retry logic for failed payments (optional)
4. ✅ Implement grace period (e.g., 3 days after failure)
5. ✅ Add email notifications (supplement in-app notifications)
6. ✅ Create admin dashboard for subscription health metrics
