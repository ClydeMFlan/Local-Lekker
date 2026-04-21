# Auto-Renewal Payment Failure Integration Example

## Quick Integration for Members Home Page

### Step 1: Add Payment Failure Alert Widget

```dart
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../features/payments/payment_failure_alert.dart';

class MembersHomePage extends StatefulWidget {
  // ... existing code

  @override
  State<MembersHomePage> createState() => _MembersHomePageState();
}

class _MembersHomePageState extends State<MembersHomePage> {
  // ... existing state variables

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.getCurrentUser();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Lekker'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ADD THIS: Payment failure alert at the top
            if (user != null)
              PaymentFailureAlert(
                userId: user.id,
                onUpdatePaymentMethod: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentOptionsScreen(
                        selectedPlan: 'monthly',
                        planDetails: {
                          'price': 99.00,
                          'frequency': 1,
                        },
                      ),
                    ),
                  );
                },
              ),
            
            // ... rest of your existing widgets
            // QR Code display, benefits list, etc.
          ],
        ),
      ),
    );
  }
}
```

### Step 2: Add Banner Version (Alternative - Compact)

For a less intrusive alert, use the banner version:

```dart
class _MembersHomePageState extends State<MembersHomePage> {
  bool _showPaymentBanner = true;
  
  Future<void> _checkPaymentStatus() async {
    final user = SupabaseService.instance.getCurrentUser();
    if (user == null) return;
    
    final hasFailure = await NotificationService()
        .hasPaymentFailureNotification(user.id);
    
    setState(() {
      _showPaymentBanner = hasFailure;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkPaymentStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Lekker'),
      ),
      body: Column(
        children: [
          // Compact banner at top
          if (_showPaymentBanner)
            PaymentFailureBanner(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentOptionsScreen(
                      selectedPlan: 'monthly',
                      planDetails: {'price': 99.00, 'frequency': 1},
                    ),
                  ),
                );
              },
              onDismiss: () {
                setState(() {
                  _showPaymentBanner = false;
                });
              },
            ),
          
          Expanded(
            child: SingleChildScrollView(
              // ... rest of your content
            ),
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Add Notification Badge to Profile/Settings

```dart
// In your app bar or profile icon
FutureBuilder<int>(
  future: NotificationService().getUnreadNotificationCount(userId),
  builder: (context, snapshot) {
    final count = snapshot.data ?? 0;
    
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.person),
          onPressed: () {
            // Navigate to profile/notifications
          },
        ),
        if (count > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  },
)
```

## Testing the Integration

### Test Payment Failure Alert

1. **Create a test notification in Supabase SQL Editor:**

```sql
-- Insert test payment failure notification
INSERT INTO notifications (
  user_id,
  title,
  message,
  type,
  is_read,
  data
) VALUES (
  'YOUR_USER_ID',  -- Replace with actual user ID
  'Payment Failed',
  'Your subscription payment could not be processed. Please update your payment method to continue enjoying Local Lekker benefits.',
  'payment_failure',
  false,
  jsonb_build_object(
    'subscription_code', 'SUB_test123',
    'failed_at', NOW(),
    'action_required', 'update_payment_method'
  )
);
```

2. **Restart the app** - The alert should appear at the top of Members Home

3. **Click "Update Payment Method"** - Should navigate to payment screen

4. **Click "Dismiss"** - Alert should disappear and notification marked as read

### Test Auto-Renewal Success

1. **Simulate webhook with successful renewal:**

```bash
curl -X POST "https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook" \
  -H "Content-Type: application/json" \
  -H "x-paystack-signature: test_signature" \
  -d '{
    "event": "subscription.charge",
    "data": {
      "status": "success",
      "amount": 9900,
      "reference": "trx_test_renewal_001",
      "subscription": {
        "subscription_code": "SUB_test123"
      },
      "customer": {
        "email": "test@example.com",
        "customer_code": "CUS_test123"
      },
      "metadata": {
        "plan_name": "monthly"
      }
    }
  }'
```

2. **Check notifications table** for renewal notification

3. **Verify subscription extended** by 30 days

## Monitoring Dashboard (Optional Enhancement)

Create an admin view to monitor subscription health:

```dart
// Admin dashboard widget
class SubscriptionHealthDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _getSubscriptionStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        final stats = snapshot.data!;
        
        return Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription Status', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                _buildStatRow('Active', stats['active'] ?? 0, Colors.green),
                _buildStatRow('Payment Failed', stats['payment_failed'] ?? 0, Colors.red),
                _buildStatRow('Expired', stats['expired'] ?? 0, Colors.orange),
                _buildStatRow('Cancelled', stats['cancelled'] ?? 0, Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatRow(String label, int count, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<Map<String, int>> _getSubscriptionStats() async {
    // Query subscriptions table and group by status
    final response = await Supabase.instance.client
        .from('subscriptions')
        .select('status');
    
    final stats = <String, int>{};
    for (var record in response) {
      final status = record['status'] as String;
      stats[status] = (stats[status] ?? 0) + 1;
    }
    
    return stats;
  }
}
```

## Summary of Changes

✅ **Webhook Enhanced:**
- `handlePaymentFailed()` now deactivates profiles and sends notifications
- `handleSubscriptionCharge()` reactivates profiles on successful renewal
- Both create in-app notifications for user awareness

✅ **Notification Service Enhanced:**
- New method: `hasPaymentFailureNotification()`
- New method: `getPaymentNotifications()`
- New method: `getLatestPaymentFailure()`

✅ **UI Components Added:**
- `PaymentFailureAlert` - Full alert card
- `PaymentFailureBanner` - Compact banner
- Both guide users to update payment method

✅ **Documentation Created:**
- Complete guide: `AUTO_RENEWAL_PAYMENT_FAILURE_GUIDE.md`
- Integration examples in this file
- Testing procedures and monitoring queries

## Next Steps

1. **Test in production** after 30 days (when first renewals occur)
2. **Monitor payment failure rate** - Target: <5%
3. **Add email notifications** (optional, supplement in-app)
4. **Implement grace period** - Give users 3-7 days to fix payment before full deactivation
5. **Add retry logic** - Attempt payment 2-3 times before marking as failed
6. **Create analytics dashboard** - Track renewal success rate, failure reasons, etc.
