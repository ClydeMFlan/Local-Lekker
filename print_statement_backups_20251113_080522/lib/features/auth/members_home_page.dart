import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_service.dart';
import '../../services/deal_approval_popup_service.dart';
import '../../services/savings_service.dart';
import '../../models/notification.dart';
import '../../widgets/custom_qr_code.dart';
import '../../services/qr_code_service.dart';
import '../../widgets/savings_summary_card.dart';
import '../payments/payments_feature.dart';
import 'welcome_page.dart';
import 'member_profile_page.dart';
import 'admin_chat_page.dart';
import 'deal_selection_page.dart';
import '../members/member_receipts_page.dart';
import 'trusted_partners_by_category_page.dart';
import '../payments/pending_payments_page.dart';

class MembersHomePage extends StatefulWidget {
  final bool hideAppBar;

  const MembersHomePage({super.key, this.hideAppBar = false});

  @override
  State<MembersHomePage> createState() => _MembersHomePageState();
}

class _MembersHomePageState extends State<MembersHomePage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DealApprovalPopupService _dealApprovalService =
      DealApprovalPopupService();
  final SavingsService _savingsService = SavingsService();
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  Map<String, dynamic>? _userQrData;
  bool _isLoading = true;
  Duration _timeUntilPayment = Duration.zero;

  Map<String, dynamic>? _subscriptionStatus;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _savingsStats;
  bool _isSubscriptionExpired = false;

  // TP key activation from QR dialog
  final TextEditingController _tpKeyDialogController = TextEditingController();
  bool _isActivatingFromDialog = false;
  bool _isSavingsLoading = true;
  int _trustedPartnersCount = 0;
  int _availableDealsCount = 0;
  bool _isLoadingPartnersCount = true;
  int _pendingPaymentsCount = 0;
  bool _isLoadingPendingPayments = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadTrustedPartnersCount();
    _loadPendingPaymentsCount();
    _subscribeToApprovalNotifications();
  }

  void _subscribeToApprovalNotifications() {
    final user = SupabaseService.instance.getCurrentUser();
    if (user == null) return;

    print('🔔 Subscribing to real-time approval notifications');
    _notificationSubscription = _dealApprovalService
        .subscribeToApprovalNotifications(user.id)
        .listen((approvalNotifications) {
          if (approvalNotifications.isNotEmpty && mounted) {
            print('🎉 New approval notification received in real-time!');
            // Show popup for the first unread approval
            _dealApprovalService.checkAndShowApprovalPopup(context, user.id);
          }
        });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _tpKeyDialogController.dispose();
    super.dispose();
  }

  Future<void> _activateTpMemberFromDialog() async {
    final key = _tpKeyDialogController.text.trim().toUpperCase();
    if (key.isEmpty || key.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 12-character key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isActivatingFromDialog = true);
    try {
      // Validate key exists
      final tpResponse = await SupabaseService.instance.client
          .from('trusted_partners')
          .select('user_id')
          .eq('unique_key', key)
          .maybeSingle();

      if (tpResponse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid Trusted Partner key'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final currentUser = SupabaseService.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Mark profile as TP member
      await SupabaseService.instance.updateUserProfile(
        userId: currentUser.id,
        profileData: {'is_tp_member': true},
      );

      // Upsert membership gateway
      await SupabaseService.instance.client.from('memberships').upsert({
        'user_id': currentUser.id,
        'role': 'member',
        'gateway': 'trusted_partner_key',
      });

      // Create or reactivate QR code (permanent)
      final existingQr = await SupabaseService.instance.client
          .from('user_qr_codes')
          .select()
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (existingQr != null) {
        await SupabaseService.instance.client
            .from('user_qr_codes')
            .update({
              'is_active': true,
              'expires_at': DateTime.now()
                  .add(const Duration(days: 36500))
                  .toIso8601String(),
            })
            .eq('user_id', currentUser.id);
      } else {
        final qrCode = await QrCodeService().generateUniqueQrCode(
          currentUser.id,
        );
        await SupabaseService.instance.client.from('user_qr_codes').insert({
          'user_id': currentUser.id,
          'qr_code': qrCode,
          'is_active': true,
          'expires_at': DateTime.now()
              .add(const Duration(days: 36500))
              .toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop(); // close dialog
        // reload data to reflect new QR
        await _loadUserData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('TP member activated. Your QR code is now active.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActivatingFromDialog = false);
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        print('🔄 Loading user data for user: ${user.id}');

        // ⏰ CHECK FOR EXPIRED SUBSCRIPTION FIRST
        final wasExpired = await _subscriptionService
            .checkAndHandleExpiredSubscription(user.id);
        if (wasExpired) {
          print('🚨 Subscription was expired - QR codes deactivated');
        }

        // Get user profile data with single() to ensure we get one record
        final profileResponse = await SupabaseService.instance.client
            .from('profiles')
            .select('name, surname, is_tp_member')
            .eq('id', user.id)
            .single();

        print('👤 User profile result: $profileResponse');
        print(
          '👤 Profile name: ${profileResponse['name']}, surname: ${profileResponse['surname']}',
        );

        // Get comprehensive subscription status
        final status = await _subscriptionService.getSubscriptionStatus(
          user.id,
        );
        print('📊 Subscription status result: $status');

        // Check if subscription is expired
        bool expired = false;
        if (status != null && status['current_period_end'] != null) {
          try {
            final renewalDate = DateTime.parse(
              status['current_period_end'],
            ).toLocal();
            if (renewalDate.isBefore(DateTime.now())) {
              expired = true;
            }
          } catch (e) {
            print('Error parsing current_period_end: $e');
          }
        }
        setState(() {
          _userProfile = profileResponse;
          _subscriptionStatus = status;
          _isSubscriptionExpired = expired;
        });

        // Also get QR code data for display
        final qrData = await _subscriptionService.getUserQrCode(user.id);
        print('📱 QR code data result: $qrData');

        // Load savings statistics
        setState(() => _isSavingsLoading = true);
        final savingsData = await _savingsService.getUserSavingsStats(user.id);
        print('💰 Savings stats result: $savingsData');

        setState(() {
          _userProfile = profileResponse;
          _subscriptionStatus = status;
          _userQrData = qrData;
          _savingsStats = savingsData;
          _isLoading = false;
          _isSavingsLoading = false;
        });

        // Check for pending approval notifications and show popup
        if (mounted) {
          await _dealApprovalService.checkAndShowApprovalPopup(
            context,
            user.id,
          );
        }

        // Show renewal popup if subscription was expired
        if (wasExpired && status != null) {
          final hasActiveQr = status['has_active_qr'] ?? false;
          final subscriptionStatus = status['subscription_status'] ?? 'none';

          // Only show popup if no active QR and subscription is expired
          if (!hasActiveQr && subscriptionStatus == 'expired') {
            print('💬 Scheduling renewal popup display');
            // Delay to ensure UI is built
            Future.delayed(Duration(milliseconds: 500), () {
              if (mounted) {
                _showRenewalPopup();
              }
            });
          }
        }

        // Start countdown timer for manual payments that are due
        if (status != null &&
            status['subscription_status'] == 'active' &&
            !(status['auto_renew'] ?? false) &&
            (status['days_until_renewal'] ?? 0) <= 3) {
          _startCountdownTimer();
        }

        // Check for pending deal approval notifications
        print('🔔 Checking for deal approval notifications');
        if (mounted) {
          await _dealApprovalService.checkAndShowApprovalPopup(
            context,
            user.id,
          );
        }
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      setState(() {
        _subscriptionStatus = null;
        _userQrData = null;
        _savingsStats = null;
        _isLoading = false;
        _isSavingsLoading = false;
      });
    }
  }

  Future<void> _loadTrustedPartnersCount() async {
    setState(() => _isLoadingPartnersCount = true);

    try {
      // Get partners count
      final partnersResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('id, owner_member_id');

      // Get all active deals with business info
      final dealsResponse = await SupabaseService.instance.client
          .from('trusted_partner_discounts')
          .select('id, name, is_active, business_id, trusted_partner_id')
          .eq('is_active', true);

      print(
        '🔍 Found ${(dealsResponse as List).length} active deals in database',
      );

      // Create a set of valid business IDs and partner IDs
      final validBusinessIds = (partnersResponse as List)
          .map((b) => b['id'])
          .toSet();
      final validPartnerIds = (partnersResponse as List)
          .map((b) => b['owner_member_id'])
          .toSet();

      // Filter deals to only include those linked to existing businesses
      final validDeals = (dealsResponse as List).where((deal) {
        final hasValidBusinessId =
            deal['business_id'] != null &&
            validBusinessIds.contains(deal['business_id']);
        final hasValidPartnerId =
            deal['trusted_partner_id'] != null &&
            validPartnerIds.contains(deal['trusted_partner_id']);
        return hasValidBusinessId || hasValidPartnerId;
      }).toList();

      print('🔢 Valid deals count: ${validDeals.length}');
      print('� Valid active deals:');
      for (var deal in validDeals) {
        print('   ✓ ${deal['name']}');
      }

      if (validDeals.length != (dealsResponse as List).length) {
        print(
          '⚠️ Found ${(dealsResponse as List).length - validDeals.length} orphaned deals:',
        );
        for (var deal in dealsResponse) {
          if (!validDeals.contains(deal)) {
            print(
              '   ✗ ${deal['name']} (business_id: ${deal['business_id']}, partner_id: ${deal['trusted_partner_id']})',
            );
          }
        }
      }

      setState(() {
        _trustedPartnersCount = (partnersResponse as List).length;
        _availableDealsCount = validDeals.length;
        _isLoadingPartnersCount = false;
      });
    } catch (e) {
      print('❌ Error loading trusted partners count: $e');
      setState(() {
        _trustedPartnersCount = 0;
        _availableDealsCount = 0;
        _isLoadingPartnersCount = false;
      });
    }
  }

  Future<void> _loadPendingPaymentsCount() async {
    setState(() => _isLoadingPendingPayments = true);

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        setState(() {
          _pendingPaymentsCount = 0;
          _isLoadingPendingPayments = false;
        });
        return;
      }

      final pendingResponse = await SupabaseService.instance.client
          .from('deal_authorizations')
          .select('id')
          .eq('member_id', user.id)
          .eq('status', 'approved')
          .isFilter('payment_completed_at', null);

      print('💳 Found ${(pendingResponse as List).length} pending payments');

      setState(() {
        _pendingPaymentsCount = (pendingResponse as List).length;
        _isLoadingPendingPayments = false;
      });
    } catch (e) {
      print('❌ Error loading pending payments count: $e');
      setState(() {
        _pendingPaymentsCount = 0;
        _isLoadingPendingPayments = false;
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

  void _showQrCodePopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final viewInsets = MediaQuery.of(context).viewInsets.bottom;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(bottom: viewInsets > 0 ? 10 : 0),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your QR Code',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Use the existing QR code content logic
                    _buildQrCodeContent(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Show renewal popup when subscription is expired
  void _showRenewalPopup() {
    print('🔔 Showing renewal popup for expired subscription');

    showDialog(
      context: context,
      barrierDismissible: false, // User must tap a button
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Subscription Expired',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your subscription has expired and your QR code has been deactivated.',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 16),
                Text(
                  'Renew now to:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                _buildBenefitRow('✓ Reactivate your QR code'),
                _buildBenefitRow('✓ Continue receiving instant discounts'),
                _buildBenefitRow('✓ Access exclusive local deals'),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'R99.00 for 30 days',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
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
                print('❌ User dismissed renewal popup');
                Navigator.of(context).pop();
              },
              child: Text('Not Now', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                print('✅ User clicked Renew Subscription');
                Navigator.of(context).pop();
                _navigateToPaymentScreen();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text('Renew Subscription', style: TextStyle(fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBenefitRow(String text) {
    return Padding(
      padding: EdgeInsets.only(left: 8, bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
    );
  }

  Future<void> _navigateToPaymentScreen() async {
    print('🚀 Navigating to payment screen...');
    print('📊 Current subscription data: $_userQrData');

    if (_userQrData?['subscriptions']?.first != null) {
      final subscription = _userQrData?['subscriptions']?.first;
      if (subscription != null) {
        print('📋 Subscription plan: ${subscription['plan_name']}');
        print('🔄 Auto renew: ${subscription['auto_renew']}');
      }
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          selectedPlan: 'renewal',
          planDetails: {
            'name': 'Subscription Renewal',
            'price': 99,
            'currency': 'ZAR',
            'frequency': 1, // Monthly renewal
            'description': 'Monthly subscription',
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
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              toolbarHeight: 100,
              title: Image.asset(
                'assets/locallekker_logo.png',
                height: 200,
                fit: BoxFit.contain,
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MemberProfilePage(),
                      ),
                    );
                  },
                  tooltip: 'My Profile',
                ),
                // Trusted Partners quick access
                IconButton(
                  icon: const Icon(Icons.storefront_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const TrustedPartnersByCategoryPage(),
                      ),
                    );
                  },
                  tooltip: 'Trusted Partners',
                ),
                IconButton(
                  icon: const Icon(Icons.support_agent),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminChatPage(),
                      ),
                    );
                  },
                  tooltip: 'Support',
                ),
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
                      MaterialPageRoute(
                        builder: (context) => const WelcomePage(),
                      ),
                    );
                  },
                  tooltip: 'Logout',
                ),
              ],
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                () {
                                  final name = _userProfile?['name'] ?? 'User';
                                  final surname =
                                      _userProfile?['surname'] ?? '';
                                  // Only append surname if it's not empty and not already in name
                                  if (surname.isNotEmpty &&
                                      !name.contains(surname)) {
                                    return '$name $surname';
                                  }
                                  return name;
                                }(),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.teal,
                          ),
                          onPressed: _showQrCodePopup,
                          tooltip: 'Show QR Code',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Savings Summary Card
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SavingsSummaryCard(
                    totalSpent: _savingsStats?['totalSpent']?.toDouble() ?? 0.0,
                    totalSaved: _savingsStats?['totalSaved']?.toDouble() ?? 0.0,
                    totalPaid: _savingsStats?['totalPaid']?.toDouble() ?? 0.0,
                    totalTips: _savingsStats?['totalTips']?.toDouble() ?? 0.0,
                    totalDeals: _savingsStats?['totalDeals'] ?? 0,
                    isLoading: _isSavingsLoading,
                    onBrowseDeals: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DealSelectionPage(),
                        ),
                      );
                    },
                    onViewReceipts: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MemberReceiptsPage(),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Trusted Partners List
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TrustedPartnersByCategoryPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.storefront_outlined,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Trusted Partners',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _isLoadingPartnersCount
                                      ? const Text(
                                          'Loading...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70,
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$_trustedPartnersCount ${_trustedPartnersCount == 1 ? 'partner' : 'partners'} • $_availableDealsCount ${_availableDealsCount == 1 ? 'deal' : 'deals'}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.white70,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Pending Payments Card
                if (_pendingPaymentsCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PendingPaymentsPage(),
                          ),
                        ).then((_) {
                          // Refresh count when returning from pending payments page
                          _loadPendingPaymentsCount();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.orange.shade400,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withAlpha(76),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(51),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: const Icon(
                                Icons.pending_actions,
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pending Payments',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _isLoadingPendingPayments
                                      ? const Text(
                                          'Loading...',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70,
                                          ),
                                        )
                                      : Text(
                                          '$_pendingPaymentsCount ${_pendingPaymentsCount == 1 ? 'deal awaiting payment' : 'deals awaiting payment'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.white70,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (_pendingPaymentsCount > 0) const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQrCodeContent() {
    // Don't check _isLoading here - this is called from a dialog after data is loaded
    // If we get here, the user clicked the QR icon, so data should already be available

    if (_isSubscriptionExpired) {
      print(
        '📱 UI State: Subscription expired - show inactive QR and renewal prompt',
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
                  print('🔘 Approve Renewal button pressed (expired case)');
                  _navigateToPaymentScreen();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Approve Renewal'),
              ),
            ],
          ),
        ),
      );
    }

    // Check if user has QR code but no subscription (TP member case)
    if (_subscriptionStatus == null && _userQrData != null) {
      print('📱 UI State: TP member with QR code but no subscription');
      final hasActiveQr = _userQrData?['is_active'] ?? false;
      if (hasActiveQr) {
        // TP member with active QR code
        return _buildActiveQrCode();
      }
    }

    if (_subscriptionStatus == null) {
      print('📱 UI State: _subscriptionStatus is null - TP activation inline');

      // No QR code and no subscription - allow inline TP key activation
      if (_userQrData == null) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.qr_code, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No QR Code Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you have a Trusted Partner key, paste it below to activate your membership and QR code immediately.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tpKeyDialogController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 12,
                  decoration: const InputDecoration(
                    labelText: 'Trusted Partner Key',
                    prefixIcon: Icon(Icons.vpn_key),
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isActivatingFromDialog
                      ? null
                      : _activateTpMemberFromDialog,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isActivatingFromDialog
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Activate'),
                ),
              ],
            ),
          ),
        );
      }

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
                  print(
                    '🔘 Renew Subscription button pressed (no subscription data case)',
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

    print('📊 UI State Debug:');
    print('  - has_active_qr: $hasActiveQr');
    print('  - auto_renew: $autoRenew');
    print('  - days_until_renewal: $daysUntilRenewal');
    print('  - subscription_status: $subscriptionStatus');

    // Show Renew Subscription button for inactive QR with manual payments
    if (!hasActiveQr && !autoRenew) {
      print(
        '📱 UI State: Inactive QR for manual payment user - showing "Renew Subscription" button',
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
                  print(
                    '🔘 Renew Subscription button pressed (inactive QR case)',
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
      print('📱 UI State: Showing QR with countdown');
      return _buildQrWithCountdown();
    }

    // Show active QR code
    print('📱 UI State: Showing active QR code');
    return _buildActiveQrCode();
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
    // Check if user is TP member (permanent QR code, no renewal needed)
    final isTpMember = _userProfile?['is_tp_member'] ?? false;

    // Get the subscription renewal date (current_period_end)
    final renewalDate = _subscriptionStatus?['current_period_end'];
    String validityText = 'Valid until renewal';

    if (isTpMember) {
      validityText = 'Permanent - No renewal needed';
    } else if (renewalDate != null) {
      try {
        final endDate = DateTime.parse(renewalDate);
        validityText =
            'Valid until ${endDate.day} ${_getMonthName(endDate.month)} ${endDate.year}';
      } catch (e) {
        print('Error parsing renewal date: $e');
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
