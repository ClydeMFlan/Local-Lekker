import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_service.dart';
import '../../services/deal_approval_popup_service.dart';
import '../../services/savings_service.dart';
import '../../services/cache_service.dart';
import '../../models/notification.dart';
import '../../widgets/custom_qr_code.dart';
import '../../widgets/savings_summary_card.dart';
import '../payments/payments_feature.dart';
import 'welcome_page.dart';
import 'member_profile_page.dart';
import 'admin_chat_page.dart';
import '../chat/chat_list_page.dart';
import '../../services/chat_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'deal_selection_page.dart';
import '../members/member_receipts_page.dart';
import 'trusted_partners_by_category_page.dart';
import '../payments/pending_payments_page.dart';
import 'widgets/trusted_partner_key_dialog.dart';
import 'promotion_detail_page.dart';
import '../../services/promotion_campaign_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MembersHomePage extends StatefulWidget {
  final bool hideAppBar;

  const MembersHomePage({super.key, this.hideAppBar = false});

  @override
  State<MembersHomePage> createState() => _MembersHomePageState();
}

class _MembersHomePageState extends State<MembersHomePage>
  with WidgetsBindingObserver {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DealApprovalPopupService _dealApprovalService =
      DealApprovalPopupService();
  final SavingsService _savingsService = SavingsService();
  final CacheService _cacheService = CacheService.instance;
  StreamSubscription<List<NotificationModel>>? _notificationSubscription;
  Map<String, dynamic>? _userQrData;
  Duration _timeUntilPayment = Duration.zero;

  Map<String, dynamic>? _subscriptionStatus;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _savingsStats;
  bool _isSubscriptionExpired = false;

  bool _isSavingsLoading = true;
  int _trustedPartnersCount = 0;
  int _availableDealsCount = 0;
  bool _isLoadingPartnersCount = true;
  int _pendingPaymentsCount = 0;
  bool _isLoadingPendingPayments = true;
  bool _isTrustedPartner = false;
  DateTime? _lastApprovalSyncAt;
  bool _isResubscribingApprovals = false;

  // Promotions
  List<Map<String, dynamic>> _activePromotions = [];

  // Unread chat count for AppBar badge
  int _unreadChatCount = 0;
  Timer? _unreadChatTimer;
  RealtimeChannel? _chatMessagesChannel;

  // City/Area filter
  String? _selectedProvince;
  String? _selectedCity;
  bool _isLoadingCities = true;

  static const Map<String, List<String>> _citiesByProvince = {
    'Eastern Cape': [
      'Bhisho',
      'Butterworth',
      'Cradock',
      'East London',
      'Graaff-Reinet',
      'Grahamstown (Makhanda)',
      'Jeffreys Bay',
      'King William\'s Town',
      'Mthatha',
      'Port Elizabeth (Gqeberha)',
      'Queenstown',
      'Uitenhage',
    ],
    'Free State': [
      'Bethlehem',
      'Bloemfontein',
      'Kroonstad',
      'Parys',
      'Phuthaditjhaba',
      'Sasolburg',
      'Virginia',
      'Welkom',
    ],
    'Gauteng': [
      'Alberton',
      'Benoni',
      'Boksburg',
      'Brakpan',
      'Carletonville',
      'Centurion',
      'Germiston',
      'Johannesburg',
      'Krugersdorp',
      'Midrand',
      'Pretoria',
      'Randburg',
      'Roodepoort',
      'Sandton',
      'Soweto',
      'Springs',
      'Vanderbijlpark',
      'Vereeniging',
    ],
    'KwaZulu-Natal': [
      'Ballito',
      'Durban',
      'Empangeni',
      'Eshowe',
      'Ladysmith',
      'Margate',
      'Newcastle',
      'Pietermaritzburg',
      'Pinetown',
      'Port Shepstone',
      'Richards Bay',
      'Ulundi',
      'Umhlanga',
    ],
    'Limpopo': [
      'Bela-Bela',
      'Giyani',
      'Lephalale',
      'Louis Trichardt (Makhado)',
      'Mokopane',
      'Musina',
      'Phalaborwa',
      'Polokwane',
      'Thohoyandou',
      'Tzaneen',
    ],
    'Mpumalanga': [
      'Barberton',
      'Bethal',
      'Ermelo',
      'Middelburg',
      'Nelspruit (Mbombela)',
      'Secunda',
      'Standerton',
      'Witbank (Emalahleni)',
    ],
    'Northern Cape': [
      'De Aar',
      'Kathu',
      'Kimberley',
      'Kuruman',
      'Springbok',
      'Upington',
    ],
    'North West': [
      'Brits',
      'Klerksdorp',
      'Lichtenburg',
      'Mahikeng',
      'Potchefstroom',
      'Rustenburg',
    ],
    'Western Cape': [
      'Beaufort West',
      'Cape Town',
      'George',
      'Hermanus',
      'Knysna',
      'Mossel Bay',
      'Oudtshoorn',
      'Paarl',
      'Saldanha',
      'Somerset West',
      'Stellenbosch',
      'Swellendam',
      'Worcester',
    ],
  };

  static const List<String> _provinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
    _loadTrustedPartnersCount();
    _loadPendingPaymentsCount();
    _loadMemberCityProvince();
    _loadActivePromotions();
    _subscribeToApprovalNotifications();
    _loadUnreadChatCount();
    _unreadChatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadUnreadChatCount(),
    );
    try {
      _chatMessagesChannel = ChatService.instance
          .subscribeToChatMessageChanges(onChange: _loadUnreadChatCount);
    } catch (_) {}
  }

  Future<void> _loadUnreadChatCount() async {
    try {
      final count = await ChatService.instance.fetchUnreadConversationCount();
      if (!mounted) return;
      if (count != _unreadChatCount) {
        setState(() => _unreadChatCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadActivePromotions() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      final email = user.email;
      if (email == null || email.isEmpty) return;

      // Only show promotions the admin has registered this member's email for
      final eligiblePromos = await PromotionCampaignService()
          .getEligiblePromotionsForEmail(email: email);

      // Filter out promos the member has already signed up for
      if (eligiblePromos.isNotEmpty) {
        final signups = await SupabaseService.instance.client
            .from('promotion_signups')
            .select('promotion_id')
            .eq('user_id', user.id);

        final signedUpIds = (signups as List)
            .map((s) => s['promotion_id'] as String)
            .toSet();

        eligiblePromos.removeWhere((p) => signedUpIds.contains(p['id']));
      }

      if (mounted) {
        setState(() {
          _activePromotions = eligiblePromos;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading promotions: $e');
      }
    }
  }

  void _subscribeToApprovalNotifications() {
    final user = SupabaseService.instance.getCurrentUser();
    if (user == null) return;

    _notificationSubscription?.cancel();

    if (kDebugMode) {
      print('🔔 Subscribing to real-time approval notifications');
    }
    _notificationSubscription = _dealApprovalService
        .subscribeToApprovalNotifications(user.id)
        .listen(
          (approvalNotifications) {
            if (approvalNotifications.isNotEmpty && mounted) {
              if (kDebugMode) {
                print('🎉 New approval notification received in real-time!');
              }
              // Show popup for the first unread approval
              _dealApprovalService.checkAndShowApprovalPopup(context, user.id);
            }
          },
          onError: (error) {
            if (kDebugMode) {
              print('❌ Approval notification stream error: $error');
            }
            unawaited(_refreshApprovalNotificationsOnResume());
          },
          onDone: () {
            if (kDebugMode) {
              print('⚠️ Approval notification stream closed');
            }
            unawaited(_refreshApprovalNotificationsOnResume());
          },
        );
  }

  Future<void> _refreshApprovalNotificationsOnResume() async {
    if (_isResubscribingApprovals) return;

    final user = SupabaseService.instance.getCurrentUser();
    if (user == null) return;

    final now = DateTime.now();
    final shouldThrottle =
        _lastApprovalSyncAt != null &&
        now.difference(_lastApprovalSyncAt!).inSeconds < 3;
    if (shouldThrottle) return;

    _isResubscribingApprovals = true;
    _lastApprovalSyncAt = now;

    try {
      _subscribeToApprovalNotifications();

      // Fallback query path in case realtime events were missed while backgrounded.
      if (mounted) {
        await _dealApprovalService.checkAndShowApprovalPopup(context, user.id);
      }
    } finally {
      _isResubscribingApprovals = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshApprovalNotificationsOnResume());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _unreadChatTimer?.cancel();
    _chatMessagesChannel?.unsubscribe();
    super.dispose();
  }

  // _activateTpMemberFromDialog removed – TP key activation is only available
  // on the Trusted Partner flow, not for normal members.

  // Placeholder to keep the file compiling if any dead references remain.
  // (none expected)

  Future<void> _loadUserData() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        if (kDebugMode) {
          print('🔄 Loading user data for user: ${user.id}');
        }

        // ⏰ CHECK FOR EXPIRED SUBSCRIPTION FIRST
        final wasExpired = await _subscriptionService
            .checkAndHandleExpiredSubscription(user.id);
        if (wasExpired) {
          if (kDebugMode) {
            print('🚨 Subscription was expired - QR codes deactivated');
          }
        }

        // Check if user is a trusted partner (has record in trusted_partners table)
        final tpCheck = await SupabaseService.instance.client
            .from('trusted_partners')
            .select('user_id')
            .eq('user_id', user.id)
            .maybeSingle();
        _isTrustedPartner = tpCheck != null;

        // Get user profile data with single() to ensure we get one record
        final profileResponse = await SupabaseService.instance.client
            .from('profiles')
            .select('name, surname, is_tp_member, city, province')
            .eq('id', user.id)
            .single();

        if (kDebugMode) {
          print('👤 User profile result: $profileResponse');
        }
        if (kDebugMode) {
          print(
            '👤 Profile name: ${profileResponse['name']}, surname: ${profileResponse['surname']}',
          );
        }

        // Get comprehensive subscription status
        final status = await _subscriptionService.getSubscriptionStatus(
          user.id,
        );
        if (kDebugMode) {
          print('📊 Subscription status result: $status');
        }

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
            if (kDebugMode) {
              print('Error parsing current_period_end: $e');
            }
          }
        }
        setState(() {
          _userProfile = profileResponse;
          _subscriptionStatus = status;
          _isSubscriptionExpired = expired;
        });

        // Also get QR code data for display
        final qrData = await _subscriptionService.getUserQrCode(user.id);
        if (kDebugMode) {
          print('📱 QR code data result: $qrData');
        }

        // Load savings statistics
        setState(() => _isSavingsLoading = true);
        final savingsData = await _savingsService.getUserSavingsStats(user.id);
        if (kDebugMode) {
          print('💰 Savings stats result: $savingsData');
        }

        setState(() {
          _userProfile = profileResponse;
          _subscriptionStatus = status;
          _userQrData = qrData;
          _savingsStats = savingsData;
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
            if (kDebugMode) {
              print('💬 Scheduling renewal popup display');
            }
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
        if (kDebugMode) {
          print('🔔 Checking for deal approval notifications');
        }
        if (mounted) {
          await _dealApprovalService.checkAndShowApprovalPopup(
            context,
            user.id,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading user data: $e');
      }
      setState(() {
        _subscriptionStatus = null;
        _userQrData = null;
        _savingsStats = null;
        _isSavingsLoading = false;
      });
    }
  }

  Future<void> _loadTrustedPartnersCount() async {
    setState(() => _isLoadingPartnersCount = true);

    try {
      // Try to get from cache first
      final cachedDeals = _cacheService.getCachedDeals();
      final cachedPartners = _cacheService.getCachedTrustedPartners();

      List<dynamic> partnersResponse;
      List<dynamic> dealsResponse;

      if (cachedPartners != null && cachedDeals != null) {
        // Use cached data for instant display
        partnersResponse = cachedPartners['partners'];
        dealsResponse = cachedDeals['deals'];
        if (kDebugMode) {
          print('⚡ Using cached deals and partners');
        }
      } else {
        // Fetch from database
        partnersResponse =
            await SupabaseService.instance.client
                    .from('businesses')
                    .select(
                      'id, owner_member_id, name, category, address, logo_url',
                    )
                as List<dynamic>;

        dealsResponse =
            await SupabaseService.instance.client
                    .from('trusted_partner_discounts')
                    .select(
                      'id, name, is_active, business_id, trusted_partner_id',
                    )
                    .eq('is_active', true)
                as List<dynamic>;

        // Cache the results
        await _cacheService.cacheTrustedPartners(
          partnersResponse.cast<Map<String, dynamic>>(),
        );
        await _cacheService.cacheDeals(
          dealsResponse.cast<Map<String, dynamic>>(),
        );
      }

      if (kDebugMode) {
        print('🔍 Found ${dealsResponse.length} active deals in database');
      }

      // Create a set of valid business IDs and partner IDs
      final validBusinessIds = partnersResponse.map((b) => b['id']).toSet();
      final validPartnerIds = partnersResponse
          .map((b) => b['owner_member_id'])
          .toSet();

      // Filter deals to only include those linked to existing businesses
      final validDeals = dealsResponse.where((deal) {
        final hasValidBusinessId =
            deal['business_id'] != null &&
            validBusinessIds.contains(deal['business_id']);
        final hasValidPartnerId =
            deal['trusted_partner_id'] != null &&
            validPartnerIds.contains(deal['trusted_partner_id']);
        return hasValidBusinessId || hasValidPartnerId;
      }).toList();

      if (kDebugMode) {
        print('🔢 Valid deals count: ${validDeals.length}');
      }
      if (kDebugMode) {
        print('� Valid active deals:');
      }
      for (var deal in validDeals) {
        if (kDebugMode) {
          print('   ✓ ${deal['name']}');
        }
      }

      if (validDeals.length != dealsResponse.length) {
        if (kDebugMode) {
          print(
            '⚠️ Found ${dealsResponse.length - validDeals.length} orphaned deals:',
          );
        }
        for (var deal in dealsResponse) {
          if (!validDeals.contains(deal)) {
            if (kDebugMode) {
              print(
                '   ✗ ${deal['name']} (business_id: ${deal['business_id']}, partner_id: ${deal['trusted_partner_id']})',
              );
            }
          }
        }
      }

      setState(() {
        _trustedPartnersCount = partnersResponse.length;
        _availableDealsCount = validDeals.length;
        _isLoadingPartnersCount = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading trusted partners count: $e');
      }
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

      if (kDebugMode) {
        print('💳 Found ${(pendingResponse as List).length} pending payments');
      }

      setState(() {
        _pendingPaymentsCount = (pendingResponse as List).length;
        _isLoadingPendingPayments = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading pending payments count: $e');
      }
      setState(() {
        _pendingPaymentsCount = 0;
        _isLoadingPendingPayments = false;
      });
    }
  }

  Future<void> _loadMemberCityProvince() async {
    setState(() => _isLoadingCities = true);
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Restore from SharedPreferences first for fast display
      final prefs = await SharedPreferences.getInstance();
      final savedProvince = prefs.getString('selected_province');
      final savedCity = prefs.getString('selected_city');

      if (savedProvince != null && _citiesByProvince.containsKey(savedProvince)) {
        final cities = _citiesByProvince[savedProvince]!;
        if (mounted) {
          setState(() {
            _selectedProvince = savedProvince;
            _selectedCity = (savedCity != null && cities.contains(savedCity)) ? savedCity : null;
            _isLoadingCities = false;
          });
        }
        return;
      }

      // Fall back to profile data
      final profile = await SupabaseService.instance.client
          .from('profiles')
          .select('city, province')
          .eq('id', user.id)
          .single();

      final profileProvince = profile['province'] as String?;
      final profileCity = profile['city'] as String?;

      if (mounted) {
        setState(() {
          if (profileProvince != null && _citiesByProvince.containsKey(profileProvince)) {
            _selectedProvince = profileProvince;
            final cities = _citiesByProvince[profileProvince]!;
            _selectedCity = (profileCity != null && cities.contains(profileCity)) ? profileCity : null;
          }
          _isLoadingCities = false;
        });

        // Persist to SharedPreferences
        if (_selectedProvince != null) {
          prefs.setString('selected_province', _selectedProvince!);
        }
        if (_selectedCity != null) {
          prefs.setString('selected_city', _selectedCity!);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading member city/province: $e');
      }
      if (mounted) {
        setState(() => _isLoadingCities = false);
      }
    }
  }

  Future<void> _updateMemberCityProvince(String? province, String? city) async {
    setState(() {
      _selectedProvince = province;
      _selectedCity = city;
    });

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (province != null) {
      prefs.setString('selected_province', province);
    } else {
      prefs.remove('selected_province');
    }
    if (city != null) {
      prefs.setString('selected_city', city);
    } else {
      prefs.remove('selected_city');
    }

    // Update profile in database
    final user = SupabaseService.instance.getCurrentUser();
    if (user != null) {
      await SupabaseService.instance.updateUserProfile(
        userId: user.id,
        profileData: {
          'province': province,
          'city': city,
        },
      );
    }
  }

  void _showCityFilterBottomSheet() {
    String? tempProvince = _selectedProvince;
    String? tempCity = _selectedCity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final cities = tempProvince != null
                ? _citiesByProvince[tempProvince!] ?? <String>[]
                : <String>[];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.teal),
                          const SizedBox(width: 8),
                          const Text(
                            'Select Province & City',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: DropdownButtonFormField<String>(
                        value: tempProvince,
                        decoration: const InputDecoration(
                          labelText: 'Province',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: _provinces.map((province) {
                          return DropdownMenuItem(
                            value: province,
                            child: Text(province),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            tempProvince = value;
                            tempCity = null;
                          });
                        },
                      ),
                    ),
                    if (tempProvince != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(tempProvince),
                          value: tempCity,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: cities.map((city) {
                            return DropdownMenuItem(
                              value: city,
                              child: Text(city),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setSheetState(() {
                              tempCity = value;
                            });
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _updateMemberCityProvince(null, null);
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: tempCity != null
                                  ? () {
                                      _updateMemberCityProvince(tempProvince, tempCity);
                                      Navigator.pop(context);
                                    }
                                  : null,
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    if (kDebugMode) {
      print('🔔 Showing renewal popup for expired subscription');
    }

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
                if (kDebugMode) {
                  print('❌ User dismissed renewal popup');
                }
                Navigator.of(context).pop();
              },
              child: Text('Not Now', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (kDebugMode) {
                  print('✅ User clicked Renew Subscription');
                }
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

  Widget _buildPromoBanner(Map<String, dynamic> promo) {
    final imageUrl = promo['image_url'] as String?;
    final freeMonths = promo['free_months'];
    final durationText =
        freeMonths != null ? '$freeMonths month(s) free' : 'Lifetime access';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PromotionDetailPage(promotion: promo),
              ),
            );
            _loadActivePromotions();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal.shade400, Colors.green.shade400],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.campaign, size: 36, color: Colors.white),
                    ),
                  ),
                )
              else
                Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade400, Colors.green.shade400],
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.campaign, size: 36, color: Colors.white),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            promo['name'] ?? 'Promotion',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.card_giftcard,
                                  size: 14, color: Colors.green.shade700),
                              const SizedBox(width: 4),
                              Text(
                                durationText,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'View Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Future<void> _navigateToPaymentScreen() async {
    if (kDebugMode) {
      print('🚀 Navigating to payment screen...');
    }
    if (kDebugMode) {
      print('📊 Current subscription data: $_userQrData');
    }

    // If user is a trusted partner, show the TP key dialog instead of payment screen
    final isTpMember = _userProfile?['is_tp_member'] ?? false;
    if (isTpMember || _isTrustedPartner) {
      final user = SupabaseService.instance.client.auth.currentUser;
      if (user != null) {
        showDialog(
          context: context,
          builder: (context) => TrustedPartnerKeyDialog(
            userId: user.id,
            onSuccess: () {
              _loadUserData();
            },
          ),
        );
        return;
      }
    }

    if (_userQrData?['subscriptions']?.first != null) {
      final subscription = _userQrData?['subscriptions']?.first;
      if (subscription != null) {
        if (kDebugMode) {
          print('📋 Subscription plan: ${subscription['plan_name']}');
        }
        if (kDebugMode) {
          print('🔄 Auto renew: ${subscription['auto_renew']}');
        }
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
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MemberProfilePage(),
                      ),
                    );
                    // Reload data in case user activated promo key or changed profile
                    _loadUserData();
                  },
                  tooltip: 'My Profile',
                ),
                // Messages
                IconButton(
                  tooltip: 'Messages',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChatListPage(),
                      ),
                    ).then((_) => _loadUnreadChatCount());
                  },
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.chat_bubble_outline),
                      if (_unreadChatCount > 0)
                        Positioned(
                          right: -6,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              _unreadChatCount > 9
                                  ? '9+'
                                  : '$_unreadChatCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Trusted Partners quick access
                IconButton(
                  icon: const Icon(Icons.storefront_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TrustedPartnersByCategoryPage(cityFilter: _selectedCity),
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

                // Promo banner
                if (_activePromotions.isNotEmpty)
                  ..._activePromotions.map((promo) => _buildPromoBanner(promo)),

                const SizedBox(height: 12),

                // Area/City Filter Dropdown
                if (!_isLoadingCities)
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        _showCityFilterBottomSheet();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: _selectedCity != null
                                  ? Colors.teal
                                  : Colors.grey,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_selectedProvince != null)
                                    Text(
                                      _selectedProvince!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  Text(
                                    _selectedCity ?? 'All Areas',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedCity != null
                                          ? Colors.teal.shade800
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_selectedCity != null)
                              GestureDetector(
                                onTap: () {
                                  _updateMemberCityProvince(null, null);
                                },
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                // Savings Summary Card
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007749), Color(0xFF4FA98A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
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
                          builder: (context) => DealSelectionPage(cityFilter: _selectedCity),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF007749), Color(0xFF4FA98A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Color(0x2E000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
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
                                TrustedPartnersByCategoryPage(cityFilter: _selectedCity),
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
                                color: Colors.white.withValues(alpha: 0.2),
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
      if (kDebugMode) {
        print(
          '📱 UI State: Subscription expired - show inactive QR and renewal prompt',
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
                  if (kDebugMode) {
                    print('🔘 Approve Renewal button pressed (expired case)');
                  }
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
      if (kDebugMode) {
        print('📱 UI State: TP member with QR code but no subscription');
      }
      final hasActiveQr = _userQrData?['is_active'] ?? false;
      if (hasActiveQr) {
        // TP member with active QR code
        return _buildActiveQrCode();
      }
    }

    if (_subscriptionStatus == null) {
      if (kDebugMode) {
        print(
          '📱 UI State: _subscriptionStatus is null',
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
                  if (kDebugMode) {
                    print(
                      '🔘 Renew Subscription button pressed (no subscription data case)',
                    );
                  }
                  _navigateToPaymentScreen();
                },
                child: const Text('Renew Subscription / Enter Promo Code'),
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

    if (kDebugMode) {
      print('📊 UI State Debug:');
    }
    if (kDebugMode) {
      print('  - has_active_qr: $hasActiveQr');
    }
    if (kDebugMode) {
      print('  - auto_renew: $autoRenew');
    }
    if (kDebugMode) {
      print('  - days_until_renewal: $daysUntilRenewal');
    }
    if (kDebugMode) {
      print('  - subscription_status: $subscriptionStatus');
    }

    // Show Renew Subscription button for inactive QR with manual payments
    if (!hasActiveQr && !autoRenew) {
      if (kDebugMode) {
        print(
          '📱 UI State: Inactive QR for manual payment user - showing "Renew Subscription" button',
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
                  if (kDebugMode) {
                    print(
                      '🔘 Renew Subscription button pressed (inactive QR case)',
                    );
                  }
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
      if (kDebugMode) {
        print('📱 UI State: Showing QR with countdown');
      }
      return _buildQrWithCountdown();
    }

    // Show active QR code
    if (kDebugMode) {
      print('📱 UI State: Showing active QR code');
    }
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
        if (kDebugMode) {
          print('Error parsing renewal date: $e');
        }
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
