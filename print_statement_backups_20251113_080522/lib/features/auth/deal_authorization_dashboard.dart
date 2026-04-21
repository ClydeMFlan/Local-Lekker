import 'package:flutter/material.dart';
import '../../models/deal_authorization.dart';
import '../../services/discount_service.dart';
import '../../services/deal_authorization_service.dart';
import '../../services/supabase_service.dart';
import 'receipt_generator_page.dart';

class DealAuthorizationDashboard extends StatefulWidget {
  const DealAuthorizationDashboard({super.key});

  @override
  State<DealAuthorizationDashboard> createState() =>
      _DealAuthorizationDashboardState();
}

class _DealAuthorizationDashboardState
    extends State<DealAuthorizationDashboard> {
  final DiscountService _discountService = DiscountService();
  final DealAuthorizationService _dealService = DealAuthorizationService();

  List<DealAuthorization> _pendingAuthorizations = [];
  List<DealAuthorization> _approvedAuthorizations = [];
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAuthorizations();
  }

  Future<void> _loadAuthorizations() async {
    setState(() => _isLoading = true);
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final allAuthorizations = await _discountService
            .getTrustedPartnerDealAuthorizations(user.id);

        print(
          '📊 Dashboard: Loaded ${allAuthorizations.length} total authorizations',
        );

        // Debug: Log payment_completed_at status for all deals
        for (var auth in allAuthorizations) {
          print(
            '📊 Deal ${auth.id.substring(0, 8)}: status=${auth.status}, paymentCompletedAt=${auth.paymentCompletedAt}',
          );
        }

        setState(() {
          _pendingAuthorizations = allAuthorizations
              .where((auth) => auth.status == 'pending')
              .toList();
          // Approved: Show ALL approved and rejected deals (both paid and unpaid)
          // Rejected deals include cancelled deals from members
          // Deals stay in Approved tab forever
          _approvedAuthorizations = allAuthorizations
              .where(
                (auth) =>
                    auth.status == 'approved' || auth.status == 'rejected',
              )
              .toList();

          print(
            '📊 Dashboard counts: Pending=${_pendingAuthorizations.length}, Approved=${_approvedAuthorizations.length}',
          );
        });

        // Load receipts for Receipts tab
        await _loadReceipts();

        // Create notifications for any existing pending authorizations
        // This ensures trusted partners get notified of pending requests
        await _discountService
            .createNotificationsForExistingPendingAuthorizations(user.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load authorizations: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadReceipts() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      print('🧾 Loading receipts for trusted partner: ${user.id}');

      final response = await SupabaseService.instance.client
          .from('deal_receipts')
          .select()
          .eq('trusted_partner_id', user.id)
          .order('created_at', ascending: false);

      print('🧾 Loaded ${response.length} receipts');

      setState(() {
        _receipts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('❌ Error loading receipts: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load receipts: $e')));
      }
    }
  }

  Future<void> _approveAuthorization(String dealId) async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      await _dealService.approveDealAuthorization(
        dealId: dealId,
        trustedPartnerId: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authorization approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadAuthorizations(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve authorization: $e')),
        );
      }
    }
  }

  Future<void> _rejectAuthorization(String dealId, String reason) async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      await _dealService.rejectDealAuthorization(
        dealId: dealId,
        trustedPartnerId: user.id,
        rejectionReason: reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authorization rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadAuthorizations(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject authorization: $e')),
        );
      }
    }
  }

  void _generateReceipt(String dealId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ReceiptGeneratorPage(dealAuthorizationId: dealId),
      ),
    );
  }

  void _showRejectDialog(String dealId) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Authorization'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                Navigator.of(context).pop();
                _rejectAuthorization(dealId, reason);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Deal Authorizations'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              fontSize: 14,
            ),
            indicator: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pending, size: 18),
                    const SizedBox(width: 4),
                    const Flexible(
                      child: Text('Pending', overflow: TextOverflow.ellipsis),
                    ),
                    if (_pendingAuthorizations.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_pendingAuthorizations.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text('Approved', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long, size: 18),
                    SizedBox(width: 4),
                    Flexible(
                      child: Text('Receipts', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAuthorizations,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAuthorizationList(_pendingAuthorizations, 'pending'),
                  _buildAuthorizationList(_approvedAuthorizations, 'approved'),
                  _buildReceiptsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildAuthorizationList(
    List<DealAuthorization> authorizations,
    String type,
  ) {
    if (authorizations.isEmpty) {
      return _buildEmptyState(type);
    }

    return RefreshIndicator(
      onRefresh: _loadAuthorizations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: authorizations.length,
        itemBuilder: (context, index) {
          final auth = authorizations[index];
          return _buildAuthorizationCard(auth, type);
        },
      ),
    );
  }

  Widget _buildReceiptsTab() {
    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Receipts Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Receipts will appear here automatically\nafter members complete payments',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAuthorizations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        itemBuilder: (context, index) {
          final receipt = _receipts[index];
          return _buildReceiptCard(receipt);
        },
      ),
    );
  }

  Widget _buildReceiptCard(Map<String, dynamic> receipt) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.receipt, color: Colors.white),
        ),
        title: Text(
          receipt['business_name'] ?? 'Business',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Receipt: ${receipt['receipt_number'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Member: ${receipt['member_name'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _formatReceiptDate(receipt['created_at']),
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'R${_formatReceiptAmount(receipt['amount'])}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
        onTap: () => _showReceiptDetails(receipt),
      ),
    );
  }

  String _formatReceiptDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }

  String _formatReceiptAmount(dynamic amount) {
    if (amount == null) return '0.00';
    try {
      final double value = amount is String
          ? double.parse(amount)
          : amount.toDouble();
      return value.toStringAsFixed(2);
    } catch (e) {
      return '0.00';
    }
  }

  void _showReceiptDetails(Map<String, dynamic> receipt) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Colors.green),
            SizedBox(width: 8),
            Text('Receipt Details'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReceiptDetailRow(
                'Receipt Number',
                receipt['receipt_number'] ?? 'N/A',
              ),
              const Divider(),
              _buildReceiptDetailRow(
                'Business',
                receipt['business_name'] ?? 'N/A',
              ),
              _buildReceiptDetailRow(
                'Discount',
                receipt['discount_name'] ?? 'N/A',
              ),
              const Divider(),
              _buildReceiptDetailRow(
                'Amount',
                'R${_formatReceiptAmount(receipt['amount'])}',
              ),
              _buildReceiptDetailRow(
                'Payment Method',
                (receipt['payment_method'] as String?)?.toUpperCase() ?? 'N/A',
              ),
              // Show note for in-store POS payments
              if ((receipt['payment_method'] as String?) == 'pos') ...[
                _buildReceiptDetailRow('Note', 'in-store payment'),
              ],
              const Divider(),
              _buildReceiptDetailRow(
                'Date',
                _formatReceiptDate(receipt['created_at']),
              ),
              const Divider(),
              _buildReceiptDetailRow('Member', receipt['member_name'] ?? 'N/A'),
              _buildReceiptDetailRow('Email', receipt['member_email'] ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildAuthorizationCard(DealAuthorization auth, String type) {
    final memberName = auth.member != null
        ? '${auth.member!.name ?? 'Unknown'} ${auth.member!.surname ?? 'Member'}'
        : 'Unknown Member';
    final discountName = auth.discount?.name ?? 'Unknown Deal';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memberName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        discountName,
                        style: TextStyle(color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(type),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.payment, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'R${auth.amount?.toStringAsFixed(2) ?? 'N/A'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Icon(
                  auth.paymentMethod == 'in_app'
                      ? Icons.phone_android
                      : Icons.store,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    auth.paymentMethod == 'in_app'
                        ? 'In-App Payment'
                        : 'In-Store Payment',
                    style: TextStyle(color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (auth.notes != null && auth.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${auth.notes}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            if (type == 'pending') _buildPendingActions(auth.id),
            if (type == 'approved') _buildApprovedActions(auth),
            if (type == 'completed') _buildCompletedActions(auth),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActions(String dealId) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _approveAuthorization(dealId),
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(dealId),
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovedActions(DealAuthorization auth) {
    // Check if deal was cancelled/rejected by member
    if (auth.status == 'rejected') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.cancel, size: 20, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                auth.rejectionReason ?? 'Cancelled by member',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    // Check if payment has been completed
    final bool paymentCompleted = auth.paymentCompletedAt != null;

    if (paymentCompleted) {
      // Payment completed - show success message
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, size: 20, color: Colors.green),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'In-app payment received. Receipt generated automatically.',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Payment not completed
    // For in-app: show waiting message
    // For in-store (POS): show a Paid button the partner can tap after member pays on POS
    if (auth.paymentMethod == 'in_app') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty, size: 20, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Waiting for member to complete payment',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // POS flow: show Paid button
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final user = SupabaseService.instance.getCurrentUser();
                  if (user == null) return;
                  await _dealService.completePOSPayment(
                    dealId: auth.id,
                    trustedPartnerId: user.id,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Marked as paid. Receipt issued.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadAuthorizations();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to complete payment: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedActions(DealAuthorization auth) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generateReceipt(auth.id),
            icon: const Icon(Icons.receipt),
            label: const Text('Generate Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String type) {
    final title = switch (type) {
      'pending' => 'No Pending Authorizations',
      'approved' => 'No Approved Authorizations',
      _ => 'No Authorizations',
    };

    final message = switch (type) {
      'pending' => 'New authorization requests will appear here',
      'approved' =>
        'Approved deals will appear here.\nReceipts are generated automatically after payment.',
      _ => 'Authorizations will appear here',
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'pending' => Colors.orange,
      'approved' => Colors.blue,
      'completed' => Colors.green,
      _ => Colors.grey,
    };
  }
}
