import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_service.dart';
import '../../widgets/custom_qr_code.dart';
import '../payments/payments_feature.dart';
import 'welcome_page.dart';
import 'user_profile_page.dart';
import 'trusted_partners_page.dart';
import 'member_bills_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final _logger = Logger();
  final SubscriptionService _subscriptionService = SubscriptionService();
  Map<String, dynamic>? _userQrData;
  bool _isLoading = true;
  Duration _timeUntilPayment = Duration.zero;

  Map<String, dynamic>? _subscriptionStatus;
  Map<String, dynamic>? _userProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        _logger.i('Loading user data for user: ${user.id}');

        // Get user profile data
        final profile = await SupabaseService.instance.client
            .from('profiles')
            .select('name, surname')
            .eq('id', user.id)
            .single();
        _logger.d('User profile result: $profile');

        // Get comprehensive subscription status
        final status = await _subscriptionService.getSubscriptionStatus(
          user.id,
        );
        _logger.d('Subscription status result: $status');

        // Also get QR code data for display
        final qrData = await _subscriptionService.getUserQrCode(user.id);
        _logger.d('QR code data result: $qrData');

        setState(() {
          _userProfile = profile;
          _subscriptionStatus = status;
          _userQrData = qrData;
          _isLoading = false;
        });

        // Start countdown timer for manual payments that are due
        if (status != null &&
            status['subscription_status'] == 'active' &&
            !(status['auto_renew'] ?? false) &&
            (status['days_until_renewal'] ?? 0) <= 3) {
          _startCountdownTimer();
        }
      }
    } catch (e) {
      _logger.e('Error loading user data: $e');
      setState(() {
        _subscriptionStatus = null;
        _userQrData = null;
        _isLoading = false;
      });
    }
  }

  void _startCountdownTimer() {
    if (_subscriptionStatus != null &&
        _subscriptionStatus?['subscription_end_date'] != null) {
      final subscriptionEndDate = DateTime.parse(
        _subscriptionStatus?['subscription_end_date'] ?? '',
      );
      _timeUntilPayment = _subscriptionService.getTimeUntilNextPayment(
        subscriptionEndDate,
      );

      // Update timer every second
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _timeUntilPayment = _subscriptionService.getTimeUntilNextPayment(
              subscriptionEndDate,
            );
          });
          _startCountdownTimer();
        }
      });
    }
  }

  void _handleManualRenewal() {
    _navigateToPaymentScreen();
  }

  Future<void> _navigateToPaymentScreen() async {
    _logger.i('Navigating to payment screen...');
    _logger.d('Current subscription data: $_userQrData');

    if (_userQrData?['subscriptions']?.first != null) {
      final subscription = _userQrData?['subscriptions']?.first;
      if (subscription != null) {
        _logger.d('Subscription plan: ${subscription['plan_name']}');
        _logger.d('Auto renew: ${subscription['auto_renew']}');
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          selectedPlan: 'renewal',
          planDetails: {
            'name': 'Subscription Renewal',
            'price': 99.00,
            'currency': 'ZAR',
            'frequency': 1, // Monthly renewal
            'description':
                'Renew your subscription to continue accessing premium features',
          },
        ),
      ),
    );

    if (result == true) {
      // Payment successful, reload data
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: Image.asset(
          'assets/locallekker_logo.png',
          height: 200,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await SupabaseService.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const WelcomePage()),
              );
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_userProfile?['name'] ?? 'User'} ${_userProfile?['surname'] ?? ''}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // QR Code Section
            Text('Your QR Code', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            // QR Code Content
            _buildQrCodeContent(),

            const SizedBox(height: 24),

            // Quick actions
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Action buttons in a grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildActionCard(
                  context,
                  'My Profile',
                  Icons.person,
                  Colors.blue,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserProfilePage(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'Trusted Partners',
                  Icons.business,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrustedPartnersPage(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'My Bills',
                  Icons.receipt,
                  Colors.orange,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MemberBillsPage(),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  context,
                  'Support',
                  Icons.help,
                  Colors.purple,
                  () {
                    // TODO: Navigate to support page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Support page coming soon!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCodeContent() {
    if (_isLoading) {
      _logger.d('UI State: Loading...');
      return const Center(child: CircularProgressIndicator());
    }

    if (_subscriptionStatus == null) {
      _logger.i(
        'UI State: _subscriptionStatus is null - showing "Renew Subscription" button',
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.qr_code, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No active subscription found',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _logger.i(
                    'Renew Subscription button pressed (no subscription data case)',
                  );
                  _navigateToPaymentScreen();
                },
                child: const Text('Renew Subscription'),
              ),
            ],
          ),
        ),
      );
    }

    final hasActiveQr = _subscriptionStatus?['has_active_qr'] ?? false;
    final autoRenew = _subscriptionStatus?['auto_renew'] ?? false;
    final daysUntilRenewal = _subscriptionStatus?['days_until_renewal'];
    final subscriptionStatus =
        _subscriptionStatus?['subscription_status'] ?? 'none';

    _logger.d('UI State Debug:');
    _logger.d('  - has_active_qr: $hasActiveQr');
    _logger.d('  - auto_renew: $autoRenew');
    _logger.d('  - days_until_renewal: $daysUntilRenewal');
    _logger.d('  - subscription_status: $subscriptionStatus');

    // Show Renew Subscription button for inactive QR with manual payments
    if (!hasActiveQr && !autoRenew) {
      _logger.i(
        'UI State: Inactive QR for manual payment user - showing "Renew Subscription" button',
      );
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.qr_code, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Subscription expired',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Renew your subscription to reactivate your QR code',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  _logger.i(
                    'Renew Subscription button pressed (inactive QR case)',
                  );
                  _navigateToPaymentScreen();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Renew Subscription'),
              ),
            ],
          ),
        ),
      );
    }

    // Show countdown for manual payments near renewal date
    if (!autoRenew && daysUntilRenewal != null && daysUntilRenewal <= 3) {
      _logger.i('UI State: Showing QR with countdown');
      return _buildQrWithCountdown();
    }

    // Show active QR code
    _logger.i('UI State: Showing active QR code');
    return _buildActiveQrCode();
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrWithCountdown() {
    // Check if subscription has expired
    final isExpired =
        _timeUntilPayment.isNegative || _timeUntilPayment == Duration.zero;
    final daysLeft = isExpired ? 0 : _timeUntilPayment.inDays;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              CustomQrCode(
                data: _userQrData?['qr_code'] ?? 'No QR Code Available',
                size: 200.0,
                logoAssetPath: 'assets/heart_flag.png',
              ),
              const SizedBox(height: 16),
              Text(
                isExpired ? 'Subscription Expired' : 'Payment Due Soon',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isExpired ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isExpired
                    ? 'Renew now to continue using QR code'
                    : 'Time remaining: ${daysLeft}d',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isExpired ? Colors.red : null,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleManualRenewal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                ),
                child: Text(isExpired ? 'Renew Subscription' : 'Renew Now'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveQrCode() {
    // Get the subscription end date
    final subscriptionEndDate = _subscriptionStatus?['subscription_end_date'];
    String validityText = 'Valid until renewal';

    if (subscriptionEndDate != null) {
      try {
        final endDate = DateTime.parse(subscriptionEndDate);
        validityText =
            'Valid until ${endDate.day} ${_getMonthName(endDate.month)} ${endDate.year}';
      } catch (e) {
        _logger.e('Error parsing subscription end date: $e');
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              CustomQrCode(
                data: _userQrData?['qr_code'] ?? 'No QR Code Available',
                size: 200.0,
                logoAssetPath: 'assets/heart_flag.png',
              ),
              const SizedBox(height: 16),
              Text(
                'Active QR Code',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(validityText, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
