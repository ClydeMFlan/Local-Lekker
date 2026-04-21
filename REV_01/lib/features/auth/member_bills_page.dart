import 'package:flutter/material.dart';
import '../../services/bill_approval_service.dart';
import 'package:local_lekker/services/paystack_service.dart';
import '../../services/supabase_service.dart';

class MemberBillsPage extends StatefulWidget {
  const MemberBillsPage({super.key});

  @override
  State<MemberBillsPage> createState() => _MemberBillsPageState();
}

class _MemberBillsPageState extends State<MemberBillsPage> {
  final BillApprovalService _approvalService = BillApprovalService();
  final PaystackService _paystackService = PaystackService();

  List<Map<String, dynamic>> _approvedBills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApprovedBills();
  }

  Future<void> _loadApprovedBills() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No authenticated user');
      }

      _approvedBills = await _approvalService.getApprovedBillsForMember(
        currentUser.id,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load approved bills: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processPayment(
    String billId,
    double amount,
    String partnerEmail,
  ) async {
    try {
      // Initiate Paystack payment
      await _paystackService.startOneTimePayment(
        itemName: 'Approved Bill Payment',
        itemDescription: 'Payment for approved bill',
        amount: amount,
        userId: partnerEmail, // Use partner email as identifier
        userEmail: partnerEmail,
      );

      // Generate a payment ID for tracking
      final paymentId = 'payment_${DateTime.now().millisecondsSinceEpoch}';

      // Mark bill as paid in-app
      await _approvalService.markBillAsPaidInApp(
        billId: billId,
        paymentId: paymentId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment initiated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _loadApprovedBills(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    }
  }

  Future<void> _markAsPaidPhysically(String billId) async {
    try {
      await _approvalService.markBillAsPaidPhysically(billId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill marked as paid physically'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      _loadApprovedBills(); // Refresh list
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to mark as paid: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Approved Bills'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _approvedBills.isEmpty
          ? const Center(
              child: Text(
                'No approved bills yet.\nScan receipts and wait for partner approval!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _approvedBills.length,
              itemBuilder: (context, index) {
                final approval = _approvedBills[index];
                final bill =
                    approval['processed_bills'] as Map<String, dynamic>;
                final partner = bill['partner'] as Map<String, dynamic>?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Partner info
                        Row(
                          children: [
                            const Icon(Icons.business, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              '${partner?['name'] ?? 'Unknown'} ${partner?['surname'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Bill details
                        Text(
                          'Original: R${bill['original_total']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        Text(
                          'Discount: R${bill['discount_amount']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(color: Colors.green),
                        ),
                        Text(
                          'Total: R${bill['discounted_total']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Approved: ${DateTime.parse(approval['reviewed_at']).toString().split(' ')[0]}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Payment method selection
                        const Text(
                          'Choose Payment Method:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _processPayment(
                                  bill['id'],
                                  bill['discounted_total'] ?? 0.0,
                                  partner?['email'] ?? '',
                                ),
                                icon: const Icon(Icons.payment),
                                label: const Text('Pay Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _markAsPaidPhysically(bill['id']),
                                icon: const Icon(Icons.handshake),
                                label: const Text('Pay at Business'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
