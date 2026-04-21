# Paystack Webhook Setup Guide

## Overview
The Paystack webhook handler is a Supabase Edge Function that processes Paystack payment events and automatically:
- Records successful payments
- Updates user subscription status
- Activates user QR codes for members
- Handles subscription lifecycle events

## Webhook URL
```
https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook
```

## Paystack Configuration

### 1. Access Paystack Dashboard
1. Log in to your Paystack dashboard
2. Navigate to **Settings** → **API Keys & Webhooks**

### 2. Configure Webhook URL
1. In the **Webhooks** section, click **Add Webhook**
2. Enter the webhook URL: `https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook`
3. Select the following events:
   - `charge.success`
   - `subscription.create`
   - `invoice.payment_failed`
   - `subscription.disable`

### 3. Save Configuration
- Click **Save** to activate the webhook
- Paystack will send a test event to verify the endpoint

## Supported Events

### charge.success
Triggered when a payment is successfully processed.
- Records payment in `payments` table
- For subscriptions: updates subscription status and activates QR code

### subscription.create
Triggered when a new subscription is created.
- Creates subscription record
- Updates user membership role
- Activates user QR code

### invoice.payment_failed
Triggered when a subscription payment fails.
- Updates subscription status to 'payment_failed'

### subscription.disable
Triggered when a subscription is cancelled.
- Updates subscription status to 'cancelled'
- Downgrades user membership
- Deactivates user QR code

## Testing

### Using the Test Script
```bash
# Make the script executable
chmod +x test_paystack_webhook.sh

# Run the test
./test_paystack_webhook.sh
```

### Manual Testing with cURL
```bash
curl -X POST "https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook" \
  -H "Content-Type: application/json" \
  -H "x-paystack-signature: test_signature" \
  -d '{
    "event": "charge.success",
    "data": {
      "reference": "test_ref_12345",
      "amount": 50000,
      "customer": {"email": "test@example.com"},
      "metadata": {
        "user_id": "test-user-id",
        "payment_type": "subscription",
        "plan_name": "premium"
      }
    }
  }'
```

## Environment Variables Required
The webhook function requires these Supabase environment variables:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PAYSTACK_SECRET_KEY`

## Database Schema
The webhook interacts with these tables:
- `payments` - Payment records
- `subscriptions` - User subscription data
- `memberships` - User role assignments
- `user_qr_codes` - QR code management
- `profiles` - User profile data

## Monitoring
- Check Supabase function logs in the dashboard
- Monitor payment records in the `payments` table
- Verify subscription status updates
- Confirm QR code activation

## Troubleshooting

### Webhook Not Receiving Events
1. Verify the webhook URL is correct
2. Check that events are selected in Paystack dashboard
3. Confirm the function is deployed and accessible

### Function Errors
1. Check Supabase function logs for error details
2. Verify environment variables are set
3. Ensure database tables exist and have proper permissions

### Payment Processing Issues
1. Verify user_id is included in payment metadata
2. Check that user exists in profiles table
3. Confirm database RLS policies allow the operations

## Security Notes
- The webhook includes signature verification (currently simplified)
- Uses Supabase service role key for admin operations
- All database operations respect RLS policies