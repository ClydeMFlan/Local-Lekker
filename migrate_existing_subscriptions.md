# Migrating Existing Subscriptions to Paystack Auto-Renewal

## Overview
This guide helps you migrate existing active subscribers to Paystack's auto-renewal system without charging them twice.

---

## Option 1: Wait for Natural Expiry (Simplest)

**Best for:** Small user base, minimal disruption

### How it works:
1. Existing members continue until their `current_period_end`
2. When expired, they see `PaymentRequiredScreen`
3. They pay → enrolled in Paystack subscription plan → auto-renewal starts

### Pros:
- ✅ Zero code changes needed
- ✅ No risk of double-charging
- ✅ Clean transition

### Cons:
- ⏳ Takes 30 days to migrate everyone
- ⚠️ Some members might not re-subscribe

### Action Required:
**None** - Your existing navigation code already handles this!

---

## Option 2: Manual Paystack Subscription Creation (Recommended)

**Best for:** Keep existing members, immediate migration, better retention

### How it works:
For each active subscriber, manually create a Paystack subscription that starts charging at their next renewal date.

### Steps:

#### 1. Export Active Subscribers
Run in Supabase SQL Editor:
```sql
SELECT 
    p.id as user_id,
    p.email,
    p.full_name,
    p.paystack_customer_code,
    s.current_period_end,
    s.status
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active'
  AND s.current_period_end > NOW()
ORDER BY s.current_period_end ASC;
```

Export as CSV.

#### 2. For Each Subscriber, Use Paystack API:

**Create Customer (if `paystack_customer_code` is null):**
```bash
curl https://api.paystack.co/customer \
  -H "Authorization: Bearer YOUR_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "first_name": "John",
    "last_name": "Doe"
  }'
```

**Create Subscription with Start Date:**
```bash
curl https://api.paystack.co/subscription \
  -H "Authorization: Bearer YOUR_SECRET_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "customer": "CUSTOMER_CODE_OR_EMAIL",
    "plan": "PLN_1ub3k02b2jjs6p7",
    "start_date": "2025-11-24T00:00:00Z"  # Their current_period_end
  }'
```

**Response will include:**
```json
{
  "status": true,
  "data": {
    "subscription_code": "SUB_xxxxxxxxx",
    "email_token": "xxxx"
  }
}
```

#### 3. Update Your Database:
```sql
UPDATE subscriptions 
SET paystack_subscription_code = 'SUB_xxxxxxxxx'
WHERE user_id = 'user-uuid-here';

-- Also update paystack_customer_code if it was created
UPDATE profiles
SET paystack_customer_code = 'CUS_xxxxxxxxx'
WHERE id = 'user-uuid-here';
```

#### 4. Verify in Paystack Dashboard:
- Go to **Subscriptions** tab
- Should see subscription status: "Active"
- Next charge date: matches `current_period_end`

---

## Option 3: Automated Migration Script (Advanced)

**Best for:** Large user base (100+ members)

Create a one-time migration script that automates Option 2.

### Implementation:

**Create:** `lib/scripts/migrate_subscriptions_to_paystack.dart`

```dart
import 'package:local_lekker/services/supabase_service.dart';
import 'package:local_lekker/services/paystack_service.dart';

Future<void> migrateSubscriptionsToPaystack() async {
  final supabase = SupabaseService.instance.client;
  final paystackService = PaystackService();
  
  // Get all active subscriptions without paystack_subscription_code
  final response = await supabase
    .from('subscriptions')
    .select('*, profiles!inner(email, full_name, paystack_customer_code)')
    .eq('status', 'active')
    .gt('current_period_end', DateTime.now().toIso8601String())
    .isFilter('paystack_subscription_code', null);
  
  final subscriptions = response as List<dynamic>;
  
  print('Found ${subscriptions.length} subscriptions to migrate');
  
  for (var sub in subscriptions) {
    try {
      final userId = sub['user_id'];
      final email = sub['profiles']['email'];
      final fullName = sub['profiles']['full_name'] ?? '';
      final currentPeriodEnd = DateTime.parse(sub['current_period_end']);
      var customerCode = sub['profiles']['paystack_customer_code'];
      
      print('Processing: $email');
      
      // 1. Create Paystack customer if doesn't exist
      if (customerCode == null) {
        customerCode = await paystackService.createOrGetCustomer(
          email: email,
          firstName: fullName.split(' ').first,
          lastName: fullName.split(' ').length > 1 ? fullName.split(' ').last : '',
        );
        
        if (customerCode != null) {
          await supabase
            .from('profiles')
            .update({'paystack_customer_code': customerCode})
            .eq('id', userId);
        }
      }
      
      // 2. Create subscription via Paystack API
      // Note: This requires a direct API call as PaystackService doesn't have this method yet
      final subscriptionCode = await _createPaystackSubscription(
        customerCode: customerCode!,
        planCode: 'PLN_1ub3k02b2jjs6p7',
        startDate: currentPeriodEnd,
      );
      
      // 3. Update local database
      if (subscriptionCode != null) {
        await supabase
          .from('subscriptions')
          .update({'paystack_subscription_code': subscriptionCode})
          .eq('id', sub['id']);
        
        print('✅ Migrated: $email → $subscriptionCode');
      }
      
    } catch (e) {
      print('❌ Error migrating ${sub['profiles']['email']}: $e');
    }
  }
  
  print('Migration complete!');
}

Future<String?> _createPaystackSubscription({
  required String customerCode,
  required String planCode,
  required DateTime startDate,
}) async {
  // This would need to be added to PaystackService
  // For now, this is a placeholder
  // Use Paystack API: POST https://api.paystack.co/subscription
  return null;
}
```

**To run:**
```bash
# Create a temporary main file
# lib/scripts/run_migration.dart
import 'migrate_subscriptions_to_paystack.dart';

void main() async {
  await migrateSubscriptionsToPaystack();
}

# Run it
flutter run lib/scripts/run_migration.dart
```

---

## Option 4: Hybrid Approach (Recommended for Production)

**Combine Option 1 + Option 2:**

1. **For subscriptions expiring soon (< 7 days):** Let them expire naturally, re-pay
2. **For subscriptions with > 7 days left:** Migrate manually via Paystack API
3. **New signups:** Already use Paystack subscription plan ✅

### Benefits:
- ✅ Minimal double-charging risk
- ✅ Fast migration of long-term subscriptions
- ✅ Simple handling of near-expiry subscriptions

---

## Comparison Table

| Method | Timeline | Effort | Risk | Retention |
|--------|----------|--------|------|-----------|
| **Wait for Expiry** | 30 days | None | Low | Medium |
| **Manual API** | 1-2 hours | Medium | Low | High |
| **Automated Script** | 1 day dev | High | Medium | High |
| **Hybrid** | 7 days | Low | Low | High |

---

## Recommended Action

**For your situation (5 active subscribers):**

Use **Option 2: Manual Paystack Subscription Creation**

### Why?
- Only 5 users - manual is faster than coding
- High retention - keeps existing customers happy
- No double-charging - subscriptions start at current expiry
- Takes ~15 minutes total

### Quick Steps:
1. Run the SQL query to export 5 users
2. For each user, make 2 API calls (customer + subscription)
3. Update database with subscription codes
4. Verify in Paystack dashboard

---

## Post-Migration Monitoring

After migration, run this query daily for a week:

```sql
-- Check subscription sync between local DB and Paystack
SELECT 
    p.email,
    s.status as local_status,
    s.current_period_end,
    s.paystack_subscription_code,
    CASE 
        WHEN s.paystack_subscription_code IS NULL THEN '❌ Not migrated'
        WHEN s.current_period_end < NOW() THEN '⚠️ Expired'
        ELSE '✅ Active'
    END as migration_status
FROM subscriptions s
JOIN profiles p ON s.user_id = p.id
WHERE s.status = 'active'
ORDER BY s.current_period_end ASC;
```

---

## Support Resources

- **Paystack Subscription API**: https://paystack.com/docs/api/subscription/
- **Create Subscription with Start Date**: https://paystack.com/docs/api/subscription/#create
- **List Subscriptions**: https://paystack.com/docs/api/subscription/#list

Need help with the migration? Let me know which option you want to pursue!
