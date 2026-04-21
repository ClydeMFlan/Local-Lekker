import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:local_lekker/services/paystack_service.dart';
import 'package:local_lekker/services/supabase_service.dart';
import 'package:local_lekker/services/payment_status_service.dart';
import 'package:local_lekker/services/subscription_service.dart';
import 'package:local_lekker/features/auth/welcome_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_lekker/services/navigation_service.dart';

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
                  // Navigate directly to payment options with basic plan
                  const selectedPlan = 'basic';
                  const planDetails = {
                    'name': 'Basic Plan',
                    'price': 99.00,
                    'description': 'Access to basic features',
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
  final _logger = Logger();
  String? _selectedPaymentMethod;
  bool _isProcessing = false;

  final List<Map<String, dynamic>> _paymentMethods = [
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
      _logger.i(
        'PaymentOptionsScreen: Saved pending payment for member $memberId',
      );
    } else {
      _logger.w(
        'PaymentOptionsScreen: Could not save pending payment - no member ID available',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Payment Method Options
            ..._paymentMethods.map((method) => _buildPaymentMethodCard(method)),
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
                        'Pay R${widget.planDetails['price']} Now',
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.planDetails['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'R${widget.planDetails['price']}/month',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.planDetails['description'],
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Billing: ${widget.planDetails['frequency'] == 12 ? 'Yearly' : 'Monthly'}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
    _logger.i('_processPayment called with method: $_selectedPaymentMethod');

    if (_selectedPaymentMethod == null) {
      _logger.w('No payment method selected, returning');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      _logger.d('Current user: ${user?.id ?? 'null'}');

      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not authenticated')),
          );
        }
        return;
      }

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

      _logger.i('Starting Paystack subscription...');
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

      // Start Paystack subscription
      await PaystackService().startSubscription(
        plan: widget.selectedPlan,
        amount: widget.planDetails['price'] as double,
        frequency: (widget.planDetails['frequency'] as num).toInt(),
        userId: user.id,
        userEmail: user.email!,
      );

      _logger.i(
        'Paystack subscription completed, marking payment as completed...',
      );
      // For demo purposes, mark payment as completed immediately
      // In production, this should be done via Paystack webhooks or return URL handling
      await PaymentStatusService().markPaymentCompleted(
        userId: user.id,
        planName: widget.selectedPlan,
        amount: widget.planDetails['price'],
        paymentMethod: _getPaymentMethodName(_selectedPaymentMethod!),
        transactionId: 'demo_${DateTime.now().millisecondsSinceEpoch}',
      );

      _logger.i('Payment marked as completed, activating QR code...');
      // Activate QR code after successful payment
      await SubscriptionService().processManualPayment(
        userId: user.id,
        planType: _validatePlanType(widget.selectedPlan),
      );

      _logger.i('QR code activated, checking database state...');
      // Check if QR code was actually activated
      final subscriptionService = SubscriptionService();
      final statusAfterPayment = await subscriptionService
          .getSubscriptionStatus(user.id);
      final qrDataAfterPayment = await subscriptionService.getUserQrCode(
        user.id,
      );

      _logger.d('Status after payment: $statusAfterPayment');
      _logger.d('QR data after payment: $qrDataAfterPayment');

      _logger.i('QR code activated, navigating to success screen...');
      // Navigate to success screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              planName: widget.selectedPlan,
              amount: widget.planDetails['price'],
            ),
          ),
        );
      }
    } catch (e) {
      _logger.e('Payment processing failed: $e');
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
      _logger.i('Payment processing completed');
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

  /// Validate and normalize plan type to ensure it's one of the valid values
  String _validatePlanType(String planType) {
    const validPlanTypes = ['basic', 'premium', 'annual'];
    if (validPlanTypes.contains(planType.toLowerCase())) {
      return planType.toLowerCase();
    }
    // Default to 'basic' if invalid plan type is provided
    _logger.w('Warning: Invalid plan type "$planType", defaulting to "basic"');
    return 'basic';
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final String planName;
  final double amount;

  const PaymentSuccessScreen({
    super.key,
    required this.planName,
    required this.amount,
  });

  Logger get _logger => Logger();

  bool get _isDevelopmentMode {
    try {
      return dotenv.env['PAYSTACK_DEVELOPMENT_MODE'] == 'true';
    } catch (e) {
      // If dotenv is not loaded, default to development mode
      _logger.w(
        'PaymentSuccessScreen: dotenv not loaded, defaulting to development mode',
      );
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 24),
              const Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _isDevelopmentMode
                    ? '🎯 Development Mode\n\nPayment simulated successfully!\n\nPlan: $planName\nAmount: R${amount.toStringAsFixed(2)}\n\nIn production, this would be a real Paystack transaction.'
                    : 'Welcome to Local Lekker!\n\nPlan: $planName\nAmount: R${amount.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  NavigationService().navigateToHomeAfterPayment(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Continue to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
