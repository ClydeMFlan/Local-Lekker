# Quick Start: Paystack Auto-Renewal Setup

## What Changed

✅ **Code Updated** - No further code changes needed:
- `PaystackService.initializeSubscription()` now uses plan codes from environment variables
- Added subscription management methods: `checkSubscriptionStatus()`, `cancelSubscription()`, `reactivateSubscription()`
- Webhook handler (`paystack-webhook`) now processes `subscription.charge` events for auto-renewal
- `.env.template` updated with plan code placeholders

## Steps to Enable Auto-Renewal

### 1. Create Plan in Paystack Dashboard (5 minutes)
1. Go to [dashboard.paystack.com](https://dashboard.paystack.com)
2. Click **Plans** in left sidebar
3. Click **"Create Plan"**
4. Fill in:
   - **Name**: `Local Lekker Monthly Membership`
   - **Amount**: `9900` (R99 in kobo)
   - **Interval**: `Monthly`
   - **Currency**: `ZAR`
5. Click **Create**
6. **Copy the Plan Code** (looks like `PLN_xxxxxxxxxx`)

### 2. Add Plan Code to Environment (1 minute)
Add this line to your `.env` file:
```bash
PAYSTACK_MONTHLY_PLAN_CODE=PLN_xxxxxxxxxx  # Replace with your actual code
```

### 3. Run Database Migration (1 minute)
In Supabase SQL Editor, run:
```bash
# File: add_paystack_subscription_code.sql
```
This adds the `paystack_subscription_code` column to track subscriptions.

### 4. Deploy Webhook Handler (2 minutes)
```bash
cd c:\Users\clyde\local_lekker
supabase functions deploy paystack-webhook --no-verify-jwt
```

Copy the deployed URL (looks like: `https://qdrotavcmmevhgveodcp.supabase.co/functions/v1/paystack-webhook`)

### 5. Configure Webhook in Paystack (2 minutes)
1. In Paystack Dashboard → **Settings** → **Webhooks**
2. Click **"Add Webhook"**
3. Paste your webhook URL from step 4
4. Select these events:
   - ✅ `subscription.create`
   - ✅ `subscription.charge` ← **Most important for renewals**
   - ✅ `subscription.disable`
5. Save

### 6. Test (5 minutes)
1. Sign up as new member
2. Complete payment with test card: `5060666666666666666` (CVV: `123`)
3. Check Paystack Dashboard → Subscriptions → Verify subscription created
4. Check Supabase → `subscriptions` table → Verify `paystack_subscription_code` populated

## How Auto-Renewal Works

1. **User signs up** → Pays R99 → Gets 30 days access
2. **After 30 days** → Paystack automatically charges card
3. **Webhook fires** → Your edge function receives `subscription.charge` event
4. **Database updates** → `expires_at` extended by 30 days, notification sent to user
5. **Repeat monthly** → Until user cancels

## Monitoring Renewals

### Check Webhook Logs
```bash
supabase functions logs paystack-webhook
```

### Check Recent Renewals in Supabase
```sql
SELECT 
    u.email,
    s.expires_at,
    s.paystack_subscription_code,
    s.updated_at
FROM subscriptions s
JOIN profiles u ON s.user_id = u.id
WHERE s.paystack_subscription_code IS NOT NULL
ORDER BY s.updated_at DESC
LIMIT 20;
```

### Check Paystack Dashboard
- **Subscriptions** tab shows all active subscriptions
- **Customers** tab shows which customers have active subscriptions
- **Webhooks** tab shows webhook delivery status (success/failed)

## Troubleshooting

### "Plan not found" error
- ✅ Verify plan code in `.env` matches exactly (PLN_xxxxx)
- ✅ Ensure plan is created in LIVE mode, not Test mode
- ✅ Restart app after updating `.env`

### Webhook not firing
- ✅ Check webhook URL is correct in Paystack dashboard
- ✅ Verify edge function deployed: `supabase functions list`
- ✅ Check webhook logs for errors: `supabase functions logs paystack-webhook`
- ✅ Test webhook manually: Paystack Dashboard → Webhooks → "Test Webhook"

### Subscription not renewing
- ✅ Check customer has valid card on file
- ✅ Verify subscription status in Paystack (should be "active")
- ✅ Check webhook delivered successfully in Paystack Dashboard
- ✅ Review edge function logs for errors

## Testing in Development

For testing without waiting 30 days:

1. **Use Test Mode in Paystack**
   - Create test plan with 1-minute interval
   - Use test card: `5060666666666666666`
   - Wait 1 minute and watch webhook fire

2. **Simulate Webhook Locally**
   ```bash
   # Install Supabase CLI ngrok integration
   supabase functions serve paystack-webhook
   
   # Use ngrok to expose local endpoint
   ngrok http 54321
   
   # Add ngrok URL to Paystack webhooks
   ```

## Cost Analysis

**Paystack Fees**: 1.5% + R2 per transaction
- R99 subscription = R99 × 1.5% + R2 = **R3.49 per transaction**
- You receive: R99 - R3.49 = **R95.51 per member per month**

**Monthly revenue** (1000 members):
- Gross: R99,000
- Paystack fees: R3,490
- Net: **R95,510**

## Support

- **Full Guide**: See `PAYSTACK_SUBSCRIPTION_SETUP_GUIDE.md`
- **Paystack Docs**: https://paystack.com/docs/payments/subscriptions/
- **Webhook Reference**: https://paystack.com/docs/payments/webhooks/
