# How to Complete the Deal Flow

## Current Status
Looking at your screenshot, you have a deal that is:
- ✅ **Created**: 20/10/2025 14:20:45
- ✅ **Approved**: 20/10/2025 16:21:09  
- ❌ **NOT PAID YET**: `payment_completed_at` is NULL
- ❌ **NO RECEIPT ISSUED**: `completed_at` is NULL

## What You Need to Do

### Step 1: Member Needs to Pay for the Approved Deal

The member should have received a notification that their deal was approved. Here's how to complete payment:

#### Option A: From Notification Popup (Recommended)
1. **Login as the member** who requested this deal
2. Open the app - you should see a popup saying "Deal Approved!"
3. The popup will show:
   - Business name
   - Discount details
   - Amount to pay
4. Click the **"Pay Now"** button in the popup
5. This opens the Paystack payment page in a webview
6. Complete the payment using a test card:
   - **Card Number**: 4084 0840 8408 4081
   - **Expiry**: Any future date (e.g., 12/25)
   - **CVV**: 408
   - **OTP**: 123456
7. Wait for payment success detection OR click the return button
8. You'll see message: "Payment recorded! Receipt will be issued by the business."

#### Option B: If Notification Dismissed
If the member already dismissed the notification:

1. **Check for a "My Deals" or "Approved Deals" page** in the app
2. Or check the **Notifications** section for the approval notification
3. Tap on the notification to open the approval popup
4. Follow steps 4-8 from Option A above

### Step 2: Verify Payment Timestamp in Supabase

After completing payment, run this query in Supabase:

```sql
SELECT 
  id,
  status,
  approved_at,
  payment_completed_at,
  completed_at
FROM deal_authorizations
ORDER BY updated_at DESC
LIMIT 5;
```

**Expected Result**:
- `status`: 'approved' (still approved, not completed yet!)
- `approved_at`: Should have timestamp
- `payment_completed_at`: Should NOW have timestamp ✅
- `completed_at`: Still NULL (receipt not issued yet)

### Step 3: Trusted Partner Issues Receipt

1. **Login as the trusted partner**
2. Go to **Deal Authorizations** dashboard
3. Click the **"POS Ready"** tab
4. You should see the deal that was just paid
5. Click the **"Issue Receipt"** button
6. Success message: "POS payment completed successfully!"

### Step 4: Verify Receipt was Created

Run this query in Supabase:

```sql
-- Check deal authorization is now completed
SELECT 
  id,
  status,
  approved_at,
  payment_completed_at,
  completed_at
FROM deal_authorizations
WHERE id = 'YOUR_DEAL_ID';

-- Check receipt was created
SELECT 
  receipt_number,
  payment_method,
  business_name,
  member_name,
  amount,
  created_at
FROM deal_receipts
WHERE deal_authorization_id = 'YOUR_DEAL_ID';
```

**Expected Result**:
- Deal authorization `status`: 'completed'
- `completed_at`: Now has timestamp ✅
- Receipt record exists in `deal_receipts` table ✅

### Step 5: Member Views Receipt

1. **Login as the member**
2. Go to home page
3. Click **"My Receipts"** button
4. You should see the receipt with:
   - Receipt number (RCP-...)
   - Business name
   - Discount name  
   - Amount
   - Date

## Troubleshooting

### "I don't see the approval notification"
- Check if notifications are working: `SELECT * FROM notifications WHERE user_id = 'MEMBER_USER_ID' ORDER BY created_at DESC;`
- The popup only shows for unread `deal_approved` notifications
- You may need to restart the app to trigger the popup check

### "Member can't find where to pay"
- The payment is triggered from the deal approval popup
- If popup was dismissed, look for a notifications screen or "My Deals" section
- As a workaround, you can manually navigate to the payment by finding where `DealPaymentWebViewPage` is used in the codebase

### "Deal doesn't appear in POS Ready tab"
- Verify `payment_completed_at` is not NULL
- Verify `status` is still 'approved' (not 'completed')
- Check the query in `deal_authorization_dashboard.dart` line 311:
  ```dart
  final posReadyAuths = _approvedAuthorizations
      .where((auth) => 
          auth.status == 'approved' && 
          auth.paymentCompletedAt != null)
      .toList();
  ```

### "Receipt generation fails"
- Check terminal logs for the exact error
- Common issues:
  - Business not found (check `businesses` table)
  - Member profile incomplete (check `profiles` table)
  - Discount not loaded (check join in query)

## Summary

Your issue is NOT a bug - the timestamps are NULL because:
1. ❌ **Member hasn't paid yet** → `payment_completed_at` NULL
2. ❌ **Trusted partner hasn't issued receipt** → `completed_at` NULL

Follow the steps above to complete the flow, and all timestamps will populate correctly!
