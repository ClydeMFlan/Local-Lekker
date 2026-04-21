import 'package:flutter/material.dart';
import 'package:local_lekker/services/paystack_service.dart';
import 'package:local_lekker/services/supabase_service.dart';
import 'package:local_lekker/services/payment_status_service.dart';
import 'package:local_lekker/services/subscription_service.dart';
import 'package:local_lekker/features/auth/welcome_page.dart';
import 'package:local_lekker/services/navigation_service.dart';
import 'package:local_lekker/services/deep_link_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:local_lekker/features/payments/paystack_webview_page.dart';
// Removed direct MembersHomePage import to enforce centralized gating

class PaymentRequiredScreen extends StatelessWidget {
  const PaymentRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Subscription'),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment,
                color: Theme.of(context).primaryColor,
                size: 80,
              ),
              const SizedBox(height: 24),
              const Text(
                'Complete Your Payment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'You\'ve successfully signed up for Local Lekker!\n\nTo access all features and start using the app, please complete your subscription payment.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Navigate directly to payment options with the single R99/month plan
                  const selectedPlan = 'subscription';
                  const planDetails = {
                    'name': 'Subscription',
                    'price': 99,
                    'description': 'Monthly subscription',
                    'frequency': 1, // months
                  };

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaymentOptionsScreen(
                        selectedPlan: selectedPlan,
                        planDetails: planDetails,
                        userId: SupabaseService.instance.getCurrentUser()?.id,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Proceed to Payment'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  // Sign out user
                  await SupabaseService.instance.signOut();
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WelcomePage(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentOptionsScreen extends StatefulWidget {
  final String selectedPlan;
  final Map<String, dynamic> planDetails;
  final String? userId; // Optional user ID for pending payment saving

  const PaymentOptionsScreen({
    super.key,
    required this.selectedPlan,
    required this.planDetails,
    this.userId,
  });

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _savedPaymentMethods = [];
  bool _isLoadingSavedMethods = true;

  final List<Map<String, dynamic>> _paymentMethodTypes = [
    {
      'id': 'credit_card',
      'name': 'Credit Card / Visa',
      'icon': Icons.credit_card,
      'description': 'Pay with your credit or debit card',
      'available': true,
    },
    {
      'id': 'google_pay',
      'name': 'Google Pay',
      'icon': Icons.account_balance_wallet,
      'description': 'Fast and secure payment with Google Pay',
      'available': true,
    },
    {
      'id': 'apple_pay',
      'name': 'Apple Pay',
      'icon': Icons.apple,
      'description': 'Secure payment with Apple Pay',
      'available': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    // Save pending payment info when screen loads
    _savePendingPayment();
    // Load saved payment methods
    _loadSavedPaymentMethods();
  }

  Future<void> _savePendingPayment() async {
    // Use provided userId if available, otherwise get current user
    String? memberId = widget.userId;
    if (memberId == null) {
      final user = SupabaseService.instance.getCurrentUser();
      memberId = user?.id;
    }

    if (memberId != null) {
      await PaymentStatusService().savePendingPayment(
        memberId: memberId,
        selectedPlan: widget.selectedPlan,
        planDetails: widget.planDetails,
      );
      print('PaymentOptionsScreen: Saved pending payment for member $memberId');
    } else {
      print(
        'PaymentOptionsScreen: Could not save pending payment - no member ID available',
      );
    }
  }

  Future<void> _loadSavedPaymentMethods() async {
    try {
      setState(() => _isLoadingSavedMethods = true);

      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        _savedPaymentMethods = await PaystackService().getSavedPaymentMethods(
          user.id,
        );
      }
    } catch (e) {
      print('Error loading saved payment methods: $e');
      _savedPaymentMethods = [];
    } finally {
      if (mounted) {
        setState(() => _isLoadingSavedMethods = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format price to remove decimal if it's .0
    String priceStr = widget.planDetails['price'].toString();
    if (priceStr.endsWith('.0')) {
      priceStr = priceStr.substring(0, priceStr.length - 2);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Options'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan Summary Card
            _buildPlanSummaryCard(),
            const SizedBox(height: 24),

            // Payment Methods Section
            const Text(
              'Choose Payment Method',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Saved Payment Methods Section
            if (_isLoadingSavedMethods) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_savedPaymentMethods.isNotEmpty) ...[
              const Text(
                'Your Saved Payment Methods',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._savedPaymentMethods.map(
                (method) => _buildSavedPaymentMethodCard(method),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
            ],

            // Add New Payment Method Section
            const Text(
              'Add New Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Payment Method Options
            ..._paymentMethodTypes.map(
              (method) => _buildPaymentMethodCard(method),
            ),

            const SizedBox(height: 32),

            // Pay Now Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedPaymentMethod != null && !_isProcessing
                    ? () => _showPaymentMethodPopup(_selectedPaymentMethod!)
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Pay R$priceStr Now',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // Security Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your payment is secured with 256-bit SSL encryption. We never store your card details.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryCard() {
    // Format price to remove decimal if it's .0
    String priceStr = widget.planDetails['price'].toString();
    if (priceStr.endsWith('.0')) {
      priceStr = priceStr.substring(0, priceStr.length - 2);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subscription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'R$priceStr/month',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Billing: monthly',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['id'];
    final isAvailable = method['available'] as bool;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isAvailable ? () => _selectPaymentMethod(method['id']) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                method['icon'],
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : isAvailable
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isAvailable
                            ? Colors.black
                            : Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      method['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: isAvailable
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isAvailable)
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: Colors.orange.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedPaymentMethodCard(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['id'];
    final methodId =
        method['id'] ??
        method['authorization_code'] ??
        'method_${method.hashCode}';
    final cardType = method['card_type'] ?? 'Card';
    final last4 = method['last4'] ?? '****';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectSavedPaymentMethod(methodId),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                _getCardIcon(cardType),
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$cardType •••• $last4',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Saved payment method',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCardIcon(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'visa':
        return Icons.credit_card;
      case 'mastercard':
        return Icons.credit_card;
      case 'amex':
      case 'american express':
        return Icons.credit_card;
      default:
        return Icons.credit_card;
    }
  }

  void _selectPaymentMethod(String methodId) {
    setState(() {
      _selectedPaymentMethod = methodId;
    });

    // Show payment method specific popup
    _showPaymentMethodPopup(methodId);
  }

  void _showPaymentMethodPopup(String methodId) {
    switch (methodId) {
      case 'credit_card':
        _showCreditCardPopup();
        break;
      case 'google_pay':
        _showGooglePayPopup();
        break;
      case 'apple_pay':
        _showApplePayPopup();
        break;
    }
  }

  void _showCreditCardPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Credit Card Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.credit_card,
                  color: Theme.of(context).primaryColor,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You will be redirected to Paystack\'s secure payment page to complete your credit card payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Amount: R${widget.planDetails['price']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plan: ${widget.planDetails['name']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Paystack provides PCI DSS compliant payment processing. Your card details are never stored on our servers.',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPaymentMethod = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processPayment();
              },
              child: const Text('Continue to Paystack'),
            ),
          ],
        );
      },
    );
  }

  void _showGooglePayPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Google Pay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: Colors.blue.shade600,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete your payment with Google Pay',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount: R${widget.planDetails['price']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan: ${widget.planDetails['name']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.verified,
                      color: Colors.green.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Pay provides fast, secure payments with your saved cards and accounts.',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPaymentMethod = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue with Google Pay'),
            ),
          ],
        );
      },
    );
  }

  void _showApplePayPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Apple Pay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.apple, color: Colors.black, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Complete your payment with Apple Pay',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Amount: R${widget.planDetails['price']}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Plan: ${widget.planDetails['name']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.touch_app,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Apple Pay provides secure payments with Touch ID or Face ID authentication.',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPaymentMethod = null;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _processPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue with Apple Pay'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processPayment() async {
    print('_processPayment called with method: $_selectedPaymentMethod');

    if (_selectedPaymentMethod == null) {
      print('No payment method selected, returning');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      print('Current user: ${user?.id ?? 'null'}');

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

      // Check if this is a saved payment method
      final isSavedMethod = _savedPaymentMethods.any(
        (method) =>
            method['id'] == _selectedPaymentMethod ||
            method['authorization_code'] == _selectedPaymentMethod,
      );

      // Show processing message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Processing payment with ${_getPaymentMethodName(_selectedPaymentMethod!)}...',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      print('Starting Paystack subscription...');
      // Validate plan details
      if (widget.planDetails['price'] == null ||
          widget.planDetails['frequency'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invalid plan details')));
        }
        return;
      }

      if (user.email == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User email is required for payment')),
          );
        }
        return;
      }

      // Development mode: immediately activate subscription and navigate home
      if (dotenv.env['PAYSTACK_DEVELOPMENT_MODE'] == 'true') {
        final ok = await SubscriptionService().processManualPayment(
          userId: user.id,
          planType: widget.selectedPlan,
        );
        if (mounted && ok) {
          NavigationService().navigateToHomeAfterPayment(context);
        }
        return;
      }

      // For saved payment methods, use existing authorization
      if (isSavedMethod) {
        print('Using saved payment method for subscription renewal');
        // Find the saved method details
        final savedMethod = _savedPaymentMethods.firstWhere(
          (method) =>
              method['id'] == _selectedPaymentMethod ||
              method['authorization_code'] == _selectedPaymentMethod,
          orElse: () => <String, dynamic>{},
        );

        if (savedMethod.isNotEmpty) {
          final authorizationCode =
              savedMethod['authorization_code'] ?? savedMethod['id'];
          // Use PaystackService to charge the saved card
          final success = await PaystackService().chargeSavedCard(
            authorizationCode: authorizationCode,
            amount: (widget.planDetails['price'] as num).toDouble(),
            userId: user.id,
            userEmail: user.email!,
          );

          if (success == 'success') {
            // Payment successful, activate subscription
            final ok = await SubscriptionService().processManualPayment(
              userId: user.id,
              planType: widget.selectedPlan,
            );
            if (mounted && ok) {
              NavigationService().navigateToHomeAfterPayment(context);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment failed. Please try again.'),
                ),
              );
            }
          }
        }
        return;
      }

      // For new payment methods, initialize Paystack subscription
      final authUrl = await PaystackService().initializeSubscription(
        plan: widget.selectedPlan,
        amount: (widget.planDetails['price'] as num).toDouble(),
        frequency: (widget.planDetails['frequency'] as num).toInt(),
        userId: user.id,
        userEmail: user.email!,
      );

      if (authUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to initialize payment. Please try again.'),
            ),
          );
        }
        return;
      }

      print(
        'Paystack subscription initiated, showing pending payment screen...',
      );

      // Open inline webview for Paystack checkout
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaystackWebViewPage(
              authorizationUrl: authUrl,
              userId: user.id,
              planType: widget.selectedPlan,
            ),
          ),
        );
      }
    } catch (e) {
      print('Payment processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
      print('Payment processing completed');
    }
  }

  String _getPaymentMethodName(String methodId) {
    switch (methodId) {
      case 'credit_card':
        return 'Credit Card';
      case 'google_pay':
        return 'Google Pay';
      case 'apple_pay':
        return 'Apple Pay';
      default:
        return 'Selected Method';
    }
  }

  void _selectSavedPaymentMethod(String methodId) {
    setState(() {
      _selectedPaymentMethod = methodId;
    });
    // For saved payment methods, proceed directly to payment processing
    _processPayment();
  }
}

class PaymentPendingScreen extends StatefulWidget {
  final String planName;
  final double amount;
  final String userId;

  const PaymentPendingScreen({
    super.key,
    required this.planName,
    required this.amount,
    required this.userId,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  bool _isCheckingPayment = false;
  StreamSubscription<String?>? _deepLinkSubscription;

  @override
  void initState() {
    super.initState();
    // Listen for deep link callbacks
    _deepLinkSubscription = DeepLinkService().linkStream.listen((link) {
      if (link != null && link.startsWith('payment_callback:')) {
        print(
          'PaymentPendingScreen: Received payment callback, checking status',
        );
        _checkPaymentStatus();
      }
    });
    // Start checking for payment status
    _checkPaymentStatus();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus() async {
    setState(() {
      _isCheckingPayment = true;
    });

    try {
      // Check subscription status
      final subscriptionService = SubscriptionService();
      final status = await subscriptionService.getSubscriptionStatus(
        widget.userId,
      );

      if (status != null &&
          status['subscription_status'] == 'active' &&
          status['has_active_qr'] == true) {
        // Payment completed successfully, navigate to home
        if (mounted) {
          NavigationService().navigateToHomeAfterPayment(context);
        }
      } else {
        // Payment still pending, check again in 3 seconds
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          _checkPaymentStatus();
        }
      }
    } catch (e) {
      print('Error checking payment status: $e');
      // Continue checking
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        _checkPaymentStatus();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Payment'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Processing Your Payment',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please complete your payment on Paystack. We\'re waiting for confirmation...\n\nPlan: ${widget.planName}\nAmount: R${widget.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_isCheckingPayment)
                const Text(
                  'Checking payment status...',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Manually check payment status
                  _checkPaymentStatus();
                },
                child: const Text('Check Payment Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
