# Receipt Flow Implementation Plan

## Current Status: ✅ TIMESTAMPS FIXED

### What Was Fixed

1. **✅ Timestamp Updates in discount_service.dart**
   - `approved_at` is now set when status changes to 'approved'
   - `completed_at` is now set when status changes to 'completed'
   
2. **✅ Payment Webview Fixed**
   - Payment now ONLY sets `payment_completed_at` timestamp
   - Status remains 'approved' (not 'completed')
   - This allows trusted partner to issue receipt later

3. **✅ DealAuthorization Model Updated**
   - Added `paymentCompletedAt` field
   - Properly parsed from database

4. **✅ POS Ready Tab Logic Fixed**
   - Now shows deals where `status='approved' AND payment_completed_at IS NOT NULL`
   - These are deals ready for receipt generation

## Complete Flow Sequence

### Member Side:
1. Member requests deal → Creates deal_authorization with `status='pending'`
2. Trusted partner approves → `status='approved'`, `approved_at` set
3. Member completes payment (Paystack) → `payment_completed_at` set, status stays 'approved'
4. Deal appears in trusted partner's "POS Ready" tab
5. Trusted partner generates receipt → `status='completed'`, `completed_at` set, receipt saved
6. Member can view receipt in receipt book

### Trusted Partner Side:
- **Pending Tab**: New requests from members
- **Approved Tab**: Approved deals waiting for payment
- **POS Ready Tab**: Deals with completed payments, ready for receipt generation
- **Complete Tab**: Deals with issued receipts

## What Still Needs Implementation

### 1. Receipt Generation Button in POS Ready Tab (CRITICAL)

**File**: `lib/features/auth/deal_authorization_dashboard.dart`

Current `_buildPOSCard()` method needs:
- "Issue Receipt" button
- Opens receipt generation dialog/page
- Inputs:
  - Auto-generated or manual receipt number
  - Amount (pre-filled from deal)
  - Any additional notes
- On submit:
  - Creates record in `deal_receipts` table
  - Sets `status='completed'` and `completed_at` timestamp
  - Moves deal to Complete tab
  - Creates notification for member

**Example Code**:
```dart
Widget _buildPOSCard(DealAuthorization auth) {
  return Card(
    child: Column(
      children: [
        // ... existing card content ...
        ElevatedButton.icon(
          onPressed: () => _issueReceipt(auth),
          icon: Icon(Icons.receipt_long),
          label: Text('Issue Receipt'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
        ),
      ],
    ),
  );
}

Future<void> _issueReceipt(DealAuthorization auth) async {
  // Generate receipt number (e.g., RCP-20251020-001)
  final receiptNumber = 'RCP-${DateTime.now().millisecondsSinceEpoch}';
  
  // Show confirmation dialog with receipt preview
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => ReceiptGenerationDialog(
      auth: auth,
      suggestedReceiptNumber: receiptNumber,
    ),
  );
  
  if (confirmed == true) {
    // Insert into deal_receipts table
    await _supabase.from('deal_receipts').insert({
      'deal_authorization_id': auth.id,
      'member_id': auth.memberId,
      'trusted_partner_id': auth.trustedPartnerId,
      'business_id': auth.trustedPartnerId, // or actual business_id
      'receipt_number': receiptNumber,
      'amount': auth.amount,
      'payment_method': 'paystack',
      'business_name': auth.businessName,
      'discount_name': auth.discount?.name,
      'member_name': '${auth.member?.name} ${auth.member?.surname}',
      'member_email': auth.member?.email,
    });
    
    // Update deal to completed
    await _discountService.updateDealAuthorizationStatus(
      dealId: auth.id,
      status: 'completed',
    );
    
    // Reload authorizations
    await _loadAuthorizations();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Receipt $receiptNumber issued successfully!')),
    );
  }
}
```

### 2. Member Receipt Book Screen (CRITICAL)

**New File**: `lib/features/members/member_receipts_page.dart`

Features:
- List all receipts from `deal_receipts` table
- Show: receipt_number, date, business_name, amount, discount_name
- Tap to view full receipt details
- Search/filter by date, business
- Export receipt as PDF (future enhancement)

**Add to Members Home Page**:
```dart
// In MembersHomePage, add Quick Action or menu item:
ListTile(
  leading: Icon(Icons.receipt_long),
  title: Text('My Receipts'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MemberReceiptsPage()),
    );
  },
),
```

**Example Receipt List**:
```dart
class MemberReceiptsPage extends StatefulWidget {
  @override
  State<MemberReceiptsPage> createState() => _MemberReceiptsPageState();
}

class _MemberReceiptsPageState extends State<MemberReceiptsPage> {
  List<Map<String, dynamic>> _receipts = [];
  
  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }
  
  Future<void> _loadReceipts() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    final response = await Supabase.instance.client
        .from('deal_receipts')
        .select()
        .eq('member_id', user.id)
        .order('created_at', ascending: false);
    
    setState(() {
      _receipts = List<Map<String, dynamic>>.from(response);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Receipts')),
      body: ListView.builder(
        itemCount: _receipts.length,
        itemBuilder: (context, index) {
          final receipt = _receipts[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(Icons.receipt),
              ),
              title: Text(receipt['business_name'] ?? 'Business'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Receipt: ${receipt['receipt_number']}'),
                  Text('Amount: R${receipt['amount']}'),
                  Text('Date: ${_formatDate(receipt['created_at'])}'),
                ],
              ),
              trailing: Text(
                'R${receipt['amount']}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              onTap: () => _showReceiptDetails(receipt),
            ),
          );
        },
      ),
    );
  }
}
```

### 3. Receipt Generation Removes from Member Payment Flow

**Current Issue**: Payment webview tries to create receipt immediately after payment.

**Solution**: Remove receipt generation from `_handleManualReturn()` in `deal_payment_webview_page.dart`.
- Payment should ONLY set `payment_completed_at`
- Show success message: "Payment completed! Your receipt will be issued shortly."
- Trusted partner issues receipt manually from POS Ready tab

### 4. Complete Tab Update

**File**: `lib/features/auth/deal_authorization_dashboard.dart`

The Complete tab loading logic is already correct:
```dart
_completedAuthorizations = allAuthorizations
    .where((auth) => auth.status == 'completed')
    .toList();
```

This will show deals where receipts have been issued.

## Testing Checklist

### Test Sequence:
1. **Member requests deal**
   - ✅ Check Pending tab shows request
   - ✅ Check `created_at` timestamp in Supabase

2. **Trusted partner approves**
   - ✅ Check Approved tab shows deal
   - ✅ Check `approved_at` timestamp in Supabase
   - ✅ Check member receives notification

3. **Member completes payment**
   - ✅ Payment webview works
   - ✅ Check `payment_completed_at` timestamp in Supabase
   - ✅ Check status is STILL 'approved' (not 'completed')
   - ✅ Check deal appears in POS Ready tab

4. **Trusted partner issues receipt**
   - ✅ Click "Issue Receipt" button in POS Ready tab
   - ✅ Receipt number generated
   - ✅ Receipt saved to `deal_receipts` table
   - ✅ Check `completed_at` timestamp in Supabase
   - ✅ Check status changed to 'completed'
   - ✅ Deal moved to Complete tab
   - ✅ Member receives notification

5. **Member views receipt**
   - ✅ Open "My Receipts" page
   - ✅ See receipt in list
   - ✅ Tap to view details
   - ✅ All fields populated correctly

## Database Verification Queries

```sql
-- Check timestamp flow for a specific deal
SELECT 
  id,
  status,
  created_at,
  approved_at,
  payment_completed_at,
  completed_at
FROM deal_authorizations
WHERE id = 'YOUR_DEAL_ID';

-- Check receipt was created
SELECT *
FROM deal_receipts
WHERE deal_authorization_id = 'YOUR_DEAL_ID';

-- Check all deals in each stage
SELECT status, COUNT(*) 
FROM deal_authorizations 
GROUP BY status;
```

## Next Steps Priority

1. **URGENT**: Implement receipt generation button in POS Ready tab
2. **URGENT**: Create member receipts viewing page
3. **HIGH**: Remove receipt generation from payment webview  
4. **MEDIUM**: Add receipt number auto-increment logic
5. **LOW**: Add PDF export for receipts
6. **LOW**: Add receipt email sending

## Notes

- Receipt numbers should follow format: `RCP-YYYYMMDD-###` (e.g., RCP-20251020-001)
- Consider adding a receipt counter table to ensure sequential numbering per business
- Receipt generation is manual by trusted partner (gives them control)
- Member sees receipt in their app after trusted partner issues it
- Both parties can access the receipt at any time via RLS policies
