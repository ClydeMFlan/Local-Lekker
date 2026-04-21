import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/paystack_service.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final Logger _logger = Logger();
  final PaystackService _paystackService = PaystackService();

  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isLoading = true;
  bool _isAddingMethod = false;
  String? _primaryMethodId;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to view payment methods'),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Load payment methods using Paystack service
      _paymentMethods = await _paystackService.getSavedPaymentMethods(
        currentUser.id,
      );
      _primaryMethodId = await _paystackService.getPrimaryPaymentMethod(
        currentUser.id,
      );

      _logger.i('Loaded ${_paymentMethods.length} payment methods');
    } catch (e) {
      _logger.e('Error loading payment methods: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading payment methods: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addPaymentMethod() async {
    try {
      setState(() => _isAddingMethod = true);

      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) return;

      // Create a small test payment to capture a new payment method
      final paymentResult = await _paystackService.startOneTimePayment(
        itemName: 'Payment Method Setup',
        itemDescription: 'Adding new payment method to your account',
        amount: 1.00, // Small amount for setup
        userId: currentUser.id,
        userEmail: currentUser.email ?? '',
      );

      final authorizationUrl = paymentResult?['authorization_url'];

      if (authorizationUrl != null && authorizationUrl.isNotEmpty) {
        // In a real implementation, you'd open this URL in a WebView
        // and handle the callback to capture the authorization code
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment method setup initiated. Complete the payment to add the method.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error adding payment method: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding payment method: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingMethod = false);
      }
    }
  }

  Future<void> _deletePaymentMethod(String methodId) async {
    try {
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) return;

      // Delete using Paystack service
      await _paystackService.deletePaymentMethod(currentUser.id, methodId);

      // Reload payment methods to reflect changes
      await _loadPaymentMethods();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment method deleted')));
      }
    } catch (e) {
      _logger.e('Error deleting payment method: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting payment method: $e')),
        );
      }
    }
  }

  Future<void> _setPrimaryMethod(String methodId) async {
    try {
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) return;

      // Set primary using Paystack service
      await _paystackService.setPrimaryPaymentMethod(currentUser.id, methodId);

      // Reload to update UI
      await _loadPaymentMethods();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Primary payment method updated')),
        );
      }
    } catch (e) {
      _logger.e('Error setting primary payment method: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating primary payment method: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
        actions: [
          IconButton(
            onPressed: _isAddingMethod ? null : _addPaymentMethod,
            icon: _isAddingMethod
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            tooltip: 'Add Payment Method',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _paymentMethods.isEmpty
          ? _buildEmptyState()
          : _buildPaymentMethodsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.credit_card, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Payment Methods',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a payment method to make purchases and manage subscriptions',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isAddingMethod ? null : _addPaymentMethod,
            icon: _isAddingMethod
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Add Payment Method'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _paymentMethods.length,
      itemBuilder: (context, index) {
        final method = _paymentMethods[index];
        final methodId =
            method['id'] ?? method['authorization_code'] ?? 'method_$index';
        final isPrimary = _primaryMethodId == methodId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getCardIcon(method['card_type'] ?? 'card'),
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            method['card_type'] ?? 'Card',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '**** **** **** ${method['last4'] ?? '****'}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            color: Colors.green.shade800,
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
                    if (!isPrimary)
                      TextButton(
                        onPressed: () => _setPrimaryMethod(methodId),
                        child: const Text('Set as Primary'),
                      ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showDeleteConfirmation(methodId),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete Payment Method',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  void _showDeleteConfirmation(String methodId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Method'),
        content: const Text(
          'Are you sure you want to delete this payment method? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deletePaymentMethod(methodId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
