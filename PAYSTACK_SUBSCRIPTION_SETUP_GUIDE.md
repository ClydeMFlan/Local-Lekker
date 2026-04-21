# Paystack Subscription Setup Guide

## Overview
This guide walks through setting up **auto-renewing subscriptions** in Paystack for Local Lekker's R99/month membership plan.

---

## Step 1: Create Subscription Plans in Paystack Dashboard

### 1.1 Login to Paystack
- Go to [dashboard.paystack.com](https://dashboard.paystack.com)
- Login with your Paystack credentials
- Ensure you're in **Live Mode** (not Test Mode) for production

### 1.2 Create Monthly Plan
1. Navigate to: **Plans** (left sidebar)
2. Click **"Create Plan"**
3. Fill in details:
   - **Plan Name**: `Local Lekker Monthly Membership`
   - **Plan Amount**: `9900` (R99.00 in kobo - Paystack uses kobo not rands)
   - **Interval**: `Monthly`
   - **Currency**: `ZAR` (South African Rand)
   - **Description**: `Monthly subscription for Local Lekker members`
   - **Send Invoices**: ✅ Enabled (optional - sends payment reminders)
   - **Send SMS**: ❌ Disabled (optional)
4. Click **"Create Plan"**
5. **Copy the Plan Code** - it will look like: `PLN_xxxxxxxxxx`

### 1.3 Optional: Create Annual Plan (Future)
If you want to offer annual subscriptions later:
- **Plan Name**: `Local Lekker Annual Membership`
- **Plan Amount**: `108900` (R1089 - 10% discount)
- **Interval**: `Annually`
- Currency/Description as above

---

## Step 2: Add Plan Codes to Environment Variables

### 2.1 Update `.env` file (Local Development)
Add these lines to your `.env` file:
```bash
# Paystack Subscription Plans
PAYSTACK_MONTHLY_PLAN_CODE=PLN_xxxxxxxxxx  # Replace with actual code from dashboard
# PAYSTACK_ANNUAL_PLAN_CODE=PLN_yyyyyyyyyy  # Optional - for future use
```

### 2.2 Update `.env.template` (Documentation)
Add the same lines to `.env.template` (with placeholder values):
```bash
# Paystack Subscription Plans
PAYSTACK_MONTHLY_PLAN_CODE=PLN_your_monthly_plan_code
# PAYSTACK_ANNUAL_PLAN_CODE=PLN_your_annual_plan_code  # Optional
```

---

## Step 3: Code Changes (Already Applied)

### 3.1 PaystackService Updates
✅ **Modified**: `initializeSubscription()` method now:
- Uses the plan code from environment variables
- Calls Paystack's subscription initialization endpoint
- Stores subscription code in metadata for tracking
- Enables auto-renewal by default

✅ **Added**: Helper methods for subscription management:
- `checkSubscriptionStatus()` - Verify subscription is active
- `cancelSubscription()` - Allow users to cancel
- `reactivateSubscription()` - Reactivate cancelled subscriptions

### 3.2 Subscription Flow
1. **User selects payment** → `PaymentOptionsScreen`
2. **Initialize subscription** → `PaystackService.initializeSubscription()`
3. **User completes payment** → Paystack webview
4. **Paystack creates subscription** → Auto-renewal enabled
5. **Webhook received** → Update local database (see Step 4)

---

## Step 4: Setup Webhook Handler (Required for Auto-Renewal)

### 4.1 Why Webhooks?
When Paystack auto-renews a subscription, it sends a webhook event. Your backend needs to:
- Receive the `subscription.charge` event
- Verify the payment succeeded
- Update the user's subscription in Supabase (extend `expires_at` by 30 days)

### 4.2 Create Supabase Edge Function
Create: `supabase/functions/paystack-webhook/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const PAYSTACK_SECRET_KEY = Deno.env.get('PAYSTACK_SECRET_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

serve(async (req) => {
  try {
    // Verify Paystack signature
    const signature = req.headers.get('x-paystack-signature')
    const body = await req.text()
    
    // TODO: Add signature verification for security
    
    const event = JSON.parse(body)
    
    if (event.event === 'subscription.charge') {
      const { customer, subscription, amount, status } = event.data
      
      if (status === 'success') {
        const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
        
        // Find user by Paystack customer code
        const { data: profile } = await supabase
          .from('profiles')
          .select('id')
          .eq('paystack_customer_code', customer.customer_code)
          .single()
        
        if (profile) {
          // Extend subscription by 30 days
          const { data: currentSub } = await supabase
            .from('subscriptions')
            .select('expires_at')
            .eq('user_id', profile.id)
            .order('created_at', { ascending: false })
            .limit(1)
            .single()
          
          const newExpiryDate = new Date(currentSub?.expires_at || new Date())
          newExpiryDate.setDate(newExpiryDate.getDate() + 30)
          
          await supabase
            .from('subscriptions')
            .update({ 
              expires_at: newExpiryDate.toISOString(),
              status: 'active',
              paystack_subscription_code: subscription.subscription_code
            })
            .eq('user_id', profile.id)
        }
      }
    }
    
    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
```

### 4.3 Deploy Edge Function
```bash
supabase functions deploy paystack-webhook --no-verify-jwt
```

### 4.4 Configure Webhook in Paystack Dashboard
1. Go to **Settings** → **Webhooks**
2. Add webhook URL: `https://your-project.supabase.co/functions/v1/paystack-webhook`
3. Select events:
   - ✅ `subscription.create`
   - ✅ `subscription.charge` (most important)
   - ✅ `subscription.disable`
   - ✅ `subscription.not_renew`
4. Save webhook

---

## Step 5: Database Schema Updates

### 5.1 Add Subscription Code Column
Add to `subscriptions` table:
```sql
ALTER TABLE subscriptions 
ADD COLUMN IF NOT EXISTS paystack_subscription_code TEXT;

CREATE INDEX IF NOT EXISTS idx_subscriptions_paystack_code 
ON subscriptions(paystack_subscription_code);
```

### 5.2 Add Customer Code to Profiles (Already exists)
✅ Column `paystack_customer_code` already exists on `profiles` table

---

## Step 6: Testing Checklist

### 6.1 Test Subscription Creation
- [ ] New member signs up
- [ ] Completes terms acceptance
- [ ] Selects Credit Card payment
- [ ] Paystack webview opens with subscription details
- [ ] Payment succeeds
- [ ] Check Paystack dashboard: Subscription created with status "active"
- [ ] Check Supabase: `subscriptions` table has `paystack_subscription_code`

### 6.2 Test Auto-Renewal (Simulate)
Since testing real renewals requires waiting 30 days, use Paystack's test mode:
1. Switch to Test Mode in dashboard
2. Create test plan with 1-minute interval
3. Use test card: `5060666666666666666` (CVV: `123`, Expiry: any future date)
4. Wait 1 minute
5. Check webhook logs in Supabase Edge Functions
6. Verify `expires_at` extended by interval period

### 6.3 Test Subscription Management
- [ ] User can view subscription status in app
- [ ] User can cancel subscription (sets non-renewal flag)
- [ ] User can reactivate cancelled subscription
- [ ] Cancelled subscriptions stop auto-renewal

---

## Step 7: User Communication

### 7.1 Email Notifications (Optional but Recommended)
Paystack can send emails for:
- Payment successful
- Payment failed (retry)
- Subscription cancelled
- Card expiring soon

Enable in: **Settings** → **Preferences** → **Customer Notifications**

### 7.2 In-App Subscription Management
Add a "Subscription" screen in member settings showing:
- Current plan name
- Next billing date (from `expires_at`)
- Payment method
- Cancel/Update buttons

---

## Important Notes

### Security
- ✅ **Always verify webhook signatures** - prevents fake webhooks
- ✅ **Use service role key** for edge function Supabase access
- ✅ **Never expose secret key** in client code

### Pricing
- Paystack charges **1.5% + R2** per transaction
- For R99 plan: ~R3.49 fee per transaction
- Consider if you absorb this or add to price

### Compliance
- Subscriptions must be **easy to cancel** per consumer protection laws
- Show clear pricing and renewal terms before payment
- Send renewal reminders (Paystack handles this)

### Fallback Handling
- If webhook fails, user's subscription expires but Paystack keeps charging
- Add daily cron job to sync Paystack subscriptions with local database:
  ```sql
  -- Check for subscriptions that expired but are still active in Paystack
  SELECT * FROM subscriptions 
  WHERE expires_at < NOW() 
  AND paystack_subscription_code IS NOT NULL;
  ```

---

## Rollback Plan

If you need to revert to one-time payments:
1. Keep old `initializeTransaction()` method (commented out)
2. Switch environment variable: `PAYSTACK_USE_SUBSCRIPTIONS=false`
3. Code checks this flag and uses appropriate method

---

## Support Resources

- **Paystack Docs**: https://paystack.com/docs/payments/subscriptions/
- **Paystack Dashboard**: https://dashboard.paystack.com
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions
- **Test Cards**: https://paystack.com/docs/payments/test-payments/

---

## Next Steps After Setup

1. ✅ Create monthly plan in Paystack dashboard
2. ✅ Add plan code to `.env`
3. ✅ Test subscription creation with test card
4. ✅ Deploy webhook edge function
5. ✅ Configure webhook in Paystack dashboard
6. ✅ Test webhook with ngrok/test mode
7. ✅ Add subscription management UI in app
8. ✅ Deploy to production
9. ✅ Monitor first renewals (30 days after launch)
