import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'dart:async';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/discount_service.dart';
import '../../services/push_notification_service.dart';
import '../../models/discount.dart';
import 'welcome_page.dart';
import 'business_profile_page.dart';
import 'discount_management_page.dart';
import 'discount_selection_page.dart';
import 'members_home_page.dart';
import 'member_profile_page.dart';
import 'trusted_partners_by_category_page.dart';
import 'admin_chat_page.dart';
import 'trusted_partner_inbox_page.dart';
import '../../services/chat_service.dart';
import '../business/bill_approval_page.dart';
import 'deal_authorization_dashboard.dart';
import '../business/trusted_partner_analytics_dashboard.dart';
import '../../widgets/trusted_partner_analytics_widget.dart';
import '../../widgets/branded_app_bar.dart';
import 'package:flutter/foundation.dart';

/// Local Lekker brand palette used across the Trusted Partner screen.
const Color kBrandBlue = Color(0xFF001489); // primary navy blue
const Color kBrandGreen = Color(0xFF2E7D32); // success / member toggle
const Color kBrandYellow = Color(0xFFFFB81C); // accent / highlight
class TrustedPartnerHomePage extends StatefulWidget {
  const TrustedPartnerHomePage({super.key});

  @override
  State<TrustedPartnerHomePage> createState() => _TrustedPartnerHomePageState();
}

class _TrustedPartnerHomePageState extends State<TrustedPartnerHomePage>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  bool _isDarkMode = false;
  bool _isMemberView = false;
  MobileScannerController? _scannerController;
  bool _cameraReady = false;
  String? _cameraError;
  bool _isScannerOpen = false;
  final DiscountService _discountService = DiscountService();
  List<Discount> _discounts = [];
  bool _discountsLoading = true;
  DateTime? _lastScanTime;
  static const double _headerToggleSlotWidth = 148;
  static const double _headerActionSlotWidth = 46;
  static const double _headerActionSlotHeight = 74;
  static const double _headerIconButtonFaceSize = 38;
  static const double _headerIconButtonCornerRadius = 12;
  static const double _headerCompactToggleSlotWidth = 100;
  static const double _headerCompactActionSlotWidth = 34;
  static const double _headerCompactActionSlotHeight = 60;
  static const double _headerCompactIconButtonFaceSize = 30;
  static const double _headerCompactGap = 4;
  static const double _headerGridGap = 10;
  String? _businessName;
  String? _businessLogoUrl;
  int _pendingDealRequestsCount = 0;
  int _unreadChatCount = 0;
  bool _hasActiveBanking = false;
  String? _bankName;
  bool _bankingStatusLoading = true;
  Timer? _periodicRefreshTimer;

  // Realtime subscription for deal_authorizations
  RealtimeChannel? _dealAuthChannel;
  String? _businessId;

  // Realtime subscription for chat_messages (unread badge)
  RealtimeChannel? _chatMessagesChannel;
  final GlobalKey _settingsMenuButtonKey = GlobalKey();

  // Animation for pulsing envelope
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Animation for shutter open/close
  late AnimationController _shutterController;
  late Animation<double> _shutterAnimation;

  // Check if we're on a mobile platform that supports camera
  bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadBusinessName();
    _loadBankingStatus();
    _loadPendingDealRequestsCount();
    _loadPendingBillApprovalsCount();
    _loadUnreadChatCount();
    _setupRealtimeDealAuthSubscription();
    _setupRealtimeChatSubscription();

    // Ensure push notification listener is active for the logged-in TP user
    // TEMPORARILY DISABLED: Push notifications turned off
    // PushNotificationService().reinitializeForCurrentUser();

    // Initialize pulsing animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initialize shutter animation
    _shutterController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shutterAnimation = CurvedAnimation(
      parent: _shutterController,
      curve: Curves.easeInOut,
    );

    // Register callback for notification updates
    PushNotificationService().onNotificationsChanged = () {
      if (kDebugMode) {
        print(
          '[UI] Notifications changed, refreshing pending deal requests count',
        );
      }
      _loadPendingDealRequestsCountFast();
    };
  }

  Future<void> _initializeCamera() async {
    if (!_isMobilePlatform) return;
    try {
      final controller = MobileScannerController(
        detectionTimeoutMs: 1000,
      );
      _scannerController = controller;
      // Let MobileScanner widget handle start() via autoStart (default: true).
      // Setting _cameraReady triggers a rebuild so the widget is placed in the
      // tree and the controller starts the camera automatically.
      if (mounted) {
        setState(() {
          _cameraReady = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      _logger.e('Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _cameraError = e.toString();
          _cameraReady = false;
        });
      }
    }
  }

  Future<void> _restartCamera() async {
    if (!mounted) return;
    setState(() {
      _cameraReady = false;
      _cameraError = null;
    });
    try {
      await _scannerController?.stop();
    } catch (_) {}
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;
    // Allow native camera resources to fully release before re-creating
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _initializeCamera();
  }

  Future<void> _openScanner() async {
    setState(() => _isScannerOpen = true);
    _shutterController.forward();
    await _initializeCamera();
  }

  Future<void> _closeScanner() async {
    _shutterController.reverse();
    await Future.delayed(const Duration(milliseconds: 400));
    try {
      await _scannerController?.stop();
    } catch (_) {}
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _scannerController = null;
    if (mounted) {
      setState(() {
        _isScannerOpen = false;
        _cameraReady = false;
        _cameraError = null;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data when page becomes visible
    if (kDebugMode) {
      print('TrustedPartnerHomePage became visible, refreshing data');
    }
    _loadPendingDealRequestsCount();
    _loadPendingBillApprovalsCount();

    // Also set up a periodic refresh
    _setupPeriodicRefresh();
  }

  void _setupPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _logger.d('Periodic refresh: updating pending deal requests count');
        _loadPendingDealRequestsCountFast();
        _loadUnreadChatCount();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _loadUnreadChatCount() async {
    try {
      final count = await ChatService.instance.fetchUnreadConversationCount();
      if (!mounted) return;
      if (count != _unreadChatCount) {
        setState(() => _unreadChatCount = count);
      }
    } catch (e) {
      _logger.w('Failed to load unread chat count: $e');
    }
  }

  /// Realtime channel that refreshes the unread chat badge instantly when
  /// any chat_messages row is inserted or updated.
  void _setupRealtimeChatSubscription() {
    try {
      _chatMessagesChannel = ChatService.instance
          .subscribeToChatMessageChanges(onChange: _loadUnreadChatCount);
    } catch (e) {
      _logger.w('Failed to subscribe to chat realtime: $e');
    }
  }

  /// Set up a Supabase Realtime channel on deal_authorizations for this TP's business.
  /// This fires instantly when a member creates a new pending deal request.
  Future<void> _setupRealtimeDealAuthSubscription() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Get business ID for this trusted partner
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('id')
          .eq('owner_member_id', user.id)
          .maybeSingle();

      if (businessResponse == null) {
        _logger.w('No business found for realtime deal auth subscription');
        return;
      }

      _businessId = businessResponse['id'] as String;

      // Subscribe to INSERT events on deal_authorizations for this business
      _dealAuthChannel = SupabaseService.instance.client
          .channel('deal_auth_realtime_${user.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'deal_authorizations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: _businessId!,
            ),
            callback: (payload) {
              if (kDebugMode) {
                print('[REALTIME] New deal authorization detected: ${payload.newRecord}');
              }
              _logger.i('Realtime: New deal authorization received');
              // Immediately refresh the pending count
              _loadPendingDealRequestsCountFast();
              // Also show the push notification service callback
              // (the notification insert will trigger PushNotificationService too,
              //  but this gives us a faster path for the badge count)
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'deal_authorizations',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'business_id',
              value: _businessId!,
            ),
            callback: (payload) {
              if (kDebugMode) {
                print('[REALTIME] Deal authorization updated: ${payload.newRecord}');
              }
              // Refresh count when status changes (approve/reject)
              _loadPendingDealRequestsCountFast();
            },
          )
          .subscribe();

      _logger.i('Realtime deal authorization subscription active for business $_businessId');
    } catch (e) {
      _logger.e('Failed to set up realtime deal auth subscription: $e');
    }
  }

  /// Fast path for counting pending deal requests - no backfill, no debug queries.
  /// Used by realtime callbacks and periodic refresh for instant UI updates.
  Future<void> _loadPendingDealRequestsCountFast() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Use cached business ID if available, otherwise fetch it
      String? bizId = _businessId;
      if (bizId == null) {
        final businessResponse = await SupabaseService.instance.client
            .from('businesses')
            .select('id')
            .eq('owner_member_id', user.id)
            .maybeSingle();
        if (businessResponse == null) return;
        bizId = businessResponse['id'] as String;
        _businessId = bizId;
      }

      // Simple fast count query - just count pending authorizations
      final pendingResponse = await SupabaseService.instance.client
          .from('deal_authorizations')
          .select('id')
          .eq('business_id', bizId)
          .eq('status', 'pending');

      final pendingCount = pendingResponse.length;

      if (mounted && pendingCount != _pendingDealRequestsCount) {
        if (kDebugMode) {
          print('[FAST_COUNT] Pending deal requests: $pendingCount (was $_pendingDealRequestsCount)');
        }
        setState(() => _pendingDealRequestsCount = pendingCount);
      }
    } catch (e) {
      _logger.e('Fast pending count failed: $e');
    }
  }

  @override
  void dispose() {
    _periodicRefreshTimer?.cancel();
    _dealAuthChannel?.unsubscribe();
    _chatMessagesChannel?.unsubscribe();
    try {
      _scannerController?.stop();
    } catch (_) {}
    try {
      _scannerController?.dispose();
    } catch (_) {}
    _pulseController.dispose();
    _shutterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // When in member view, show the MembersHomePage with its own AppBar
    // and add the toggle to switch back to business view
    if (_isMemberView) {
      return _buildMemberViewWithToggle();
    }

    // Business view - show trusted partner's AppBar and content
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: BrandedAppBar(
        toolbarHeight: 100,
        actions: [
          _buildHeaderActionGrid(isMemberMode: false),
        ],
      ),
      body: _isMobilePlatform
          ? _buildMobileScannerBody()
          : _buildDesktopScannerBody(),
    );
  }

  Widget _buildMemberViewWithToggle() {
    // Wrap MembersHomePage and add toggle in the existing AppBar
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: BrandedAppBar(
        toolbarHeight: 100,
        actions: [
          _buildHeaderActionGrid(isMemberMode: true),
        ],
      ),
      body: MembersHomePage(hideAppBar: true),
    );
  }

  Widget _buildHeaderActionGrid({required bool isMemberMode}) {
    final MediaQueryData media = MediaQuery.of(context);
    final bool isCompactPortrait =
        media.orientation == Orientation.portrait && media.size.width < 600;

    final double toggleSlotWidth = isCompactPortrait
        ? _headerCompactToggleSlotWidth
        : _headerToggleSlotWidth;
    final double actionSlotWidth = isCompactPortrait
        ? _headerCompactActionSlotWidth
        : _headerActionSlotWidth;
    final double actionSlotHeight = isCompactPortrait
        ? _headerCompactActionSlotHeight
        : _headerActionSlotHeight;
    final double buttonFaceSize = isCompactPortrait
        ? _headerCompactIconButtonFaceSize
        : _headerIconButtonFaceSize;
    final double iconSize = isCompactPortrait ? 17 : 21;
    final double gridGap = isCompactPortrait ? _headerCompactGap : _headerGridGap;

    Widget buildActionButton({
      Key? slotKey,
      required String tooltip,
      required VoidCallback onPressed,
      required Widget icon,
    }) {
      return _buildHeader3DIconButton(
        slotKey: slotKey,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: icon,
        slotWidth: actionSlotWidth,
        slotHeight: actionSlotHeight,
        buttonFaceSize: buttonFaceSize,
        iconSize: iconSize,
      );
    }

    final List<Widget> slotWidgets = isMemberMode
        ? <Widget>[
            _buildHeaderModeToggle(
              slotWidth: toggleSlotWidth,
              slotHeight: actionSlotHeight,
              isCompactPortrait: isCompactPortrait,
            ),
            buildActionButton(
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
            _buildHeaderMessagesButton(),
            buildActionButton(
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
            buildActionButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
              tooltip: 'Refresh',
            ),
            buildActionButton(
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context),
              tooltip: 'Logout',
            ),
          ]
        : <Widget>[
            _buildHeaderModeToggle(
              slotWidth: toggleSlotWidth,
              slotHeight: actionSlotHeight,
              isCompactPortrait: isCompactPortrait,
            ),
            _buildHeaderMessagesButton(),
            buildActionButton(
              tooltip: 'Manage Discounts',
              onPressed: _navigateToDiscountManagement,
              icon: const Icon(Icons.discount),
            ),
            buildActionButton(
              tooltip: 'Analytics Dashboard',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const TrustedPartnerAnalyticsDashboard(),
                  ),
                );
              },
              icon: const Icon(Icons.analytics),
            ),
            buildActionButton(
              slotKey: _settingsMenuButtonKey,
              tooltip: 'Settings',
              onPressed: _openHeaderSettingsMenu,
              icon: const Icon(Icons.settings),
            ),
            buildActionButton(
              tooltip: 'Sign Out',
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout),
            ),
          ];

        final double totalWidth =
        toggleSlotWidth + (actionSlotWidth * 5) + (gridGap * 5);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: totalWidth,
        height: actionSlotHeight,
        child: Row(
          children: [
            for (int i = 0; i < slotWidgets.length; i++) ...[
              slotWidgets[i],
              if (i < slotWidgets.length - 1)
                SizedBox(width: gridGap),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMessagesButton() {
    return _buildHeader3DIconButton(
      tooltip: 'Messages',
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const TrustedPartnerInboxPage(),
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
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  _unreadChatCount > 9 ? '9+' : '$_unreadChatCount',
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
      slotWidth: _isCompactHeaderLayout ? _headerCompactActionSlotWidth : _headerActionSlotWidth,
      slotHeight:
          _isCompactHeaderLayout ? _headerCompactActionSlotHeight : _headerActionSlotHeight,
      buttonFaceSize: _isCompactHeaderLayout
          ? _headerCompactIconButtonFaceSize
          : _headerIconButtonFaceSize,
      iconSize: _isCompactHeaderLayout ? 17 : 21,
    );
  }

  bool get _isCompactHeaderLayout {
    final MediaQueryData media = MediaQuery.of(context);
    return media.orientation == Orientation.portrait && media.size.width < 600;
  }

  Future<void> _openHeaderSettingsMenu() async {
    final BuildContext? buttonContext = _settingsMenuButtonKey.currentContext;
    if (buttonContext == null) return;

    final RenderBox button = buttonContext.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    final Offset topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight =
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay);

    final String? selectedValue = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        bottomRight.dy,
        overlay.size.width - bottomRight.dx,
        overlay.size.height - topLeft.dy,
      ),
      items: _buildHeaderSettingsMenuItems(),
    );

    if (selectedValue != null && mounted) {
      _handleMenuSelection(selectedValue);
    }
  }

  List<PopupMenuEntry<String>> _buildHeaderSettingsMenuItems() {
    return <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'deal_requests',
        child: ListTile(
          leading: Icon(Icons.approval),
          title: Text('Deal Authorizations'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'scan_bills',
        child: ListTile(
          leading: Icon(Icons.camera_alt),
          title: Text('Scan Business Bills'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      const PopupMenuItem<String>(
        value: 'profile',
        child: ListTile(
          leading: Icon(Icons.person),
          title: Text('Business Profile'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
      PopupMenuItem<String>(
        value: 'theme',
        child: ListTile(
          leading: Icon(
            _isDarkMode ? Icons.light_mode : Icons.dark_mode,
          ),
          title: Text(_isDarkMode ? 'Light Mode' : 'Dark Mode'),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    ];
  }

  Widget _buildHeaderModeToggle({
    required double slotWidth,
    required double slotHeight,
    required bool isCompactPortrait,
  }) {
    final isMember = _isMemberView;
    final trackGradient = isMember
        ? const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)])
        : const LinearGradient(colors: [Color(0xFF6F7C8B), Color(0xFFB0BEC5)]);

    final double textWidth = isCompactPortrait ? 30 : 56;
    final double spacerWidth = isCompactPortrait ? 4 : 8;
    final double trackWidth = isCompactPortrait ? 50 : 64;
    final double trackHeight = isCompactPortrait ? 28 : 34;
    final double knobSize = isCompactPortrait ? 21 : 27;
    final String label = isCompactPortrait
        ? (isMember ? 'M' : 'TP')
        : (isMember ? 'Member' : 'Business');

    return SizedBox(
      width: slotWidth,
      height: slotHeight,
      child: Row(
        children: [
          SizedBox(
            width: textWidth,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isCompactPortrait ? 10 : 12,
                fontWeight: FontWeight.w800,
                color: isMember ? kBrandGreen : kBrandBlue,
              ),
            ),
          ),
          SizedBox(width: spacerWidth),
          GestureDetector(
            onTap: () => setState(() => _isMemberView = !_isMemberView),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              width: trackWidth,
              height: trackHeight,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: trackGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(2, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 2,
                    offset: const Offset(-1, -1),
                  ),
                ],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: isMember
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFE6EBF0)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader3DIconButton({
    Key? slotKey,
    required String tooltip,
    required VoidCallback onPressed,
    required Widget icon,
    required double slotWidth,
    required double slotHeight,
    required double buttonFaceSize,
    required double iconSize,
  }) {
    return SizedBox(
      key: slotKey,
      width: slotWidth,
      height: slotHeight,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          width: buttonFaceSize,
          height: buttonFaceSize,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE8EFF6)],
            ),
            borderRadius: BorderRadius.circular(_headerIconButtonCornerRadius),
            border: Border.all(
              color: const Color(0xFFD2E0EE),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(2, 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 2,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(_headerIconButtonCornerRadius),
            child: Tooltip(
              message: tooltip,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(_headerIconButtonCornerRadius),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: onPressed,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(color: kBrandBlue, size: iconSize),
                    child: icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader3DIconButtonSurface({
    required Widget icon,
  }) {
    return SizedBox(
      width: _headerActionSlotWidth,
      height: _headerActionSlotHeight,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE8EFF6)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD2E0EE)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(2, 3),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.9),
                blurRadius: 2,
                offset: const Offset(-1, -1),
              ),
            ],
          ),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Center(
              child: IconTheme(
                data: const IconThemeData(color: kBrandBlue, size: 21),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader3DPlaceholderSlot() {
    return const SizedBox(
      width: _headerActionSlotWidth,
      height: _headerActionSlotHeight,
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'deal_requests':
        _navigateToDealRequests();
        break;
      case 'approvals':
        _navigateToBillApprovals();
        break;
      case 'scan_bills':
        _scanBusinessBills();
        break;
      case 'profile':
        _navigateToBusinessProfile();
        break;
      case 'theme':
        _toggleTheme();
        break;
    }
  }

  void _navigateToBusinessProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BusinessProfilePage()),
    ).then((_) {
      // Refresh banking status when returning from business profile
      // This ensures the home screen reflects any banking updates
      if (mounted) {
        if (kDebugMode) {
          print('Returned from BusinessProfilePage, refreshing banking status');
        }
        _loadBankingStatus();
      }
    });
  }

  void _navigateToDealRequests() {
    // Await the navigation so we can refresh counts when the user returns
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DealAuthorizationDashboard(),
      ),
    ).then((_) async {
      // Refresh counts after returning from the Deal Authorizations screen
      try {
        if (mounted) {
          await _loadPendingDealRequestsCount();
          await _loadPendingBillApprovalsCount();
        }
      } catch (e) {
        if (kDebugMode) {
          print(
            'Error refreshing counts after returning from deal requests: $e',
          );
        }
      }
    });
  }

  void _navigateToBillApprovals() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BillApprovalPage()),
    );
  }

  Future<void> _navigateToDiscountManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiscountManagementPage()),
    );
    // Reload discounts when returning from discount management
    _loadDiscounts();
  }

  Future<void> _scanBusinessBills() async {
    // Bill scanning feature has been removed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill scanning feature is no longer available'),
        ),
      );
    }
  }

  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    // For a complete implementation, you'd want to use a theme provider
    // or similar state management solution to persist the theme choice
    // and apply it throughout the entire app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Theme switched to ${_isDarkMode ? 'Dark' : 'Light'} Mode',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadDiscounts() async {
    setState(() => _discountsLoading = true);
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final discounts = await _discountService.getAllTrustedPartnerDiscounts(
          user.id,
        );
        setState(() => _discounts = discounts);
      }
    } catch (e) {
      // Silently fail for now - don't show error on main screen
      if (kDebugMode) {
        print('Failed to load discounts: $e');
      }
    } finally {
      setState(() => _discountsLoading = false);
    }
  }

  Future<void> _loadBusinessName() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null) {
        final business = await SupabaseService.instance.client
            .from('businesses')
            .select('name, logo_url')
            .eq('owner_member_id', user.id)
            .maybeSingle();
        if (business != null) {
          setState(() {
            _businessName = business['name'];
            _businessLogoUrl = business['logo_url'];
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load business name: $e');
      }
    }
  }

  Future<void> _loadBankingStatus() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Check for banking details in trusted_partner_bank_accounts table
      // Query by user_id (not member_id) and check is_active flag
      final bankingData = await SupabaseService.instance.client
          .from('trusted_partner_bank_accounts')
          .select('subaccount_code, subaccount_active, bank_name, is_active')
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (bankingData != null && bankingData['is_active'] == true) {
            // Banking is active if:
            // 1. is_active flag is true
            // 2. AND (subaccount_active is true OR subaccount_code exists)
            final hasSubaccount = (bankingData['subaccount_code'] ?? '')
                .toString()
                .isNotEmpty;
            _hasActiveBanking =
                (bankingData['is_active'] == true) &&
                ((bankingData['subaccount_active'] == true) || hasSubaccount);
            _bankName = bankingData['bank_name'] as String?;
          } else {
            _hasActiveBanking = false;
            _bankName = null;
          }
          _bankingStatusLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading banking status: $e');
      }
      if (mounted) {
        setState(() {
          _bankingStatusLoading = false;
        });
      }
    }
  }

  Future<void> _loadPendingDealRequestsCount() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (kDebugMode) {
        print('Loading pending deal requests for user: ${user?.id}');
      }
      if (kDebugMode) {
        print('User email: ${user?.email}');
      }
      if (user != null) {
        // Debug: Check database state first
        await _discountService.debugDatabaseState(user.id);

        // First, ensure notifications exist for existing pending authorizations
        await _discountService
            .createNotificationsForExistingPendingAuthorizations(user.id);

        // Force a refresh of the count after backfill
        if (kDebugMode) {
          print('Forcing refresh after backfill');
        }
        await Future.delayed(
          const Duration(milliseconds: 500),
        ); // Small delay for DB consistency

        final authorizations = await _discountService
            .getTrustedPartnerDealAuthorizations(user.id);
        if (kDebugMode) {
          print('Found ${authorizations.length} total authorizations');
        }
        var pendingCount = authorizations
            .where((auth) => auth.status == 'pending')
            .length;
        if (kDebugMode) {
          print('Found $pendingCount pending authorizations');
        }
        if (kDebugMode) {
          print('Setting state: _pendingDealRequestsCount = $pendingCount');
        }
        setState(() => _pendingDealRequestsCount = pendingCount);
        if (kDebugMode) {
          print('State updated successfully');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load pending deal requests count: $e');
      }
      if (kDebugMode) {
        print('Error details: ${e.toString()}');
      }
    }
  }

  Future<void> _loadPendingBillApprovalsCount() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (kDebugMode) {
        print('Loading processed bill approvals for user: ${user?.id}');
      }
      if (user != null) {
        // Get business ID for this trusted partner
        final businessResponse = await SupabaseService.instance.client
            .from('businesses')
            .select('id')
            .eq('owner_member_id', user.id)
            .maybeSingle();

        if (businessResponse != null) {
          final businessId = businessResponse['id'];
          // Query deal_authorizations for approved/rejected statuses
          final approvals = await SupabaseService.instance.client
              .from('deal_authorizations')
              .select('id')
              .eq('business_id', businessId)
              .inFilter('status', ['approved', 'rejected']);
          if (kDebugMode) {
            print('Found ${approvals.length} processed bill approvals');
          }
          // Note: Not displaying bill approvals count in current UI
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load processed bill approvals count: $e');
      }
      if (kDebugMode) {
        print('Error details: ${e.toString()}');
      }
    }
  }

  Future<void> _toggleDiscountActive(Discount discount) async {
    try {
      await _discountService.updateDiscount(
        discount.id,
        isActive: !discount.isActive,
      );

      // Update local state
      setState(() {
        final index = _discounts.indexWhere((d) => d.id == discount.id);
        if (index != -1) {
          _discounts[index] = Discount(
            id: discount.id,
            trustedPartnerId: discount.trustedPartnerId,
            name: discount.name,
            description: discount.description,
            itemName: discount.itemName,
            itemPrice: discount.itemPrice,
            percentage: discount.percentage,
            fixedAmount: discount.fixedAmount,
            isActive: !discount.isActive,
            createdAt: discount.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Discount ${discount.isActive ? 'deactivated' : 'activated'}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update discount status'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildDiscountSummary() {
    if (_discountsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_discounts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.discount_outlined, color: Colors.grey),
              const SizedBox(height: 8),
              const Text(
                'No discounts yet',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _navigateToDiscountManagement,
                icon: const Icon(Icons.add),
                label: const Text('Create Discount'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Discounts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _navigateToDiscountManagement,
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._discounts.map(
              (discount) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Deal Image (if available)
                    if (discount.imageUrl != null &&
                        discount.imageUrl!.isNotEmpty)
                      Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            discount.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    // Deal details
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              discount.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                discount.discountDisplay,
                                style: TextStyle(
                                  color: discount.isActive
                                      ? kBrandGreen
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: discount.isActive,
                                onChanged: (value) =>
                                    _toggleDiscountActive(discount),
                                activeThumbColor: kBrandGreen,
                                activeTrackColor: kBrandGreen.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add bottom padding so content doesn't overlap with version ribbon
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildBankingStatusCard() {
    if (_bankingStatusLoading) {
      return const SizedBox.shrink();
    }

    final statusColor = _hasActiveBanking ? kBrandGreen : Colors.red;
    final statusIcon = _hasActiveBanking ? Icons.check_circle : Icons.warning;
    final statusText = _hasActiveBanking
        ? 'Banking Active'
        : 'Banking Setup Required';
    final bankText = _hasActiveBanking && _bankName != null
        ? _bankName!
        : 'Tap to configure banking details';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        child: InkWell(
          onTap: _navigateToBusinessProfile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [statusColor.withValues(alpha: 0.05), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bankText,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: statusColor, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileScannerBody() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Business Name with Logo
          if (_businessName != null && _businessName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Business Logo
                  if (_businessLogoUrl != null && _businessLogoUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(_businessLogoUrl!),
                        onBackgroundImageError: (exception, stackTrace) {
                          if (kDebugMode) {
                            print('Failed to load business logo: $exception');
                          }
                        },
                        child: _businessLogoUrl == null
                            ? const Icon(Icons.business, size: 30)
                            : null,
                      ),
                    ),
                  // Business Name
                  Flexible(
                    child: Text(
                      _businessName!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // Banking Status Card
          _buildBankingStatusCard(),

          // Quick action: Add Deal (mirrors Android CTA)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToDiscountManagement,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Deal'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Deal Authorizations Card - Always show
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Card(
              color: _pendingDealRequestsCount > 0
                  ? kBrandYellow.withValues(alpha: 0.15)
                  : Colors.grey.shade100,
              child: InkWell(
                onTap: _navigateToDealRequests,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pendingDealRequestsCount > 0
                                    ? _pulseAnimation.value
                                    : 1.0,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: kBrandYellow,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: _pendingDealRequestsCount > 0
                                        ? [
                                            BoxShadow(
                                              color: kBrandYellow.withValues(
                                                alpha: 0.45,
                                              ),
                                              blurRadius: 14,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: const Icon(
                                    Icons.mail_outline,
                                    color: kBrandBlue,
                                    size: 32,
                                  ),
                                ),
                              );
                            },
                          ),

                          if (_pendingDealRequestsCount > 0)
                            Positioned(
                              // Slight overlap outside the icon box for emphasis
                              right: -6,
                              top: -6,
                              child: ScaleTransition(
                                scale: _pulseAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _pendingDealRequestsCount > 99
                                          ? '99+'
                                          : '$_pendingDealRequestsCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Deal Authorizations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$_pendingDealRequestsCount authorization(s) pending',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          if (kDebugMode) {
                            print('Manual refresh button pressed');
                          }
                          final user = SupabaseService.instance
                              .getCurrentUser();
                          if (user != null) {
                            await _discountService.debugDatabaseState(user.id);
                          }
                          _loadPendingDealRequestsCount();
                        },
                        icon: const Icon(Icons.refresh, color: kBrandBlue),
                        tooltip: 'Refresh Count',
                      ),
                      const Icon(Icons.arrow_forward_ios, color: kBrandBlue),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Approval History card removed
          const SizedBox.shrink(),

          // Analytics Widget - Shows key business metrics
          const TrustedPartnerAnalyticsWidget(),

          // QR Scanner Section - Shutter Style
          _buildScannerShutter(),

          // Discount Summary Section
          Container(
            margin: const EdgeInsets.all(16),
            child: _buildDiscountSummary(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerShutter() {
    return AnimatedBuilder(
      animation: _shutterAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isScannerOpen
                  ? [kBrandBlue, const Color(0xFF000B5C)]
                  : [Colors.grey.shade800, Colors.grey.shade900],
            ),
            boxShadow: [
              BoxShadow(
                color: (_isScannerOpen ? kBrandBlue : Colors.grey).withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header bar with title and close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Scanner',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isScannerOpen
                                ? 'Point at member QR code'
                                : 'Tap to scan member QR',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isScannerOpen)
                      IconButton(
                        onPressed: _closeScanner,
                        icon: const Icon(Icons.close, color: Colors.white70),
                        tooltip: 'Close scanner',
                      ),
                  ],
                ),
              ),

              // Scanner viewport or shutter
              GestureDetector(
                onTap: _isScannerOpen ? null : _openScanner,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: _isScannerOpen ? 240 : 100,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _isScannerOpen ? Colors.black : Colors.transparent,
                    border: Border.all(
                      color: _isScannerOpen
                          ? kBrandYellow
                          : Colors.white.withValues(alpha: 0.2),
                      width: _isScannerOpen ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _isScannerOpen
                        ? _buildActiveScannerView()
                        : _buildClosedShutterView(),
                  ),
                ),
              ),

              // Bottom hint
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isScannerOpen ? Icons.flash_on : Icons.touch_app,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isScannerOpen
                          ? 'Scanner active — hold steady'
                          : 'Tap to open camera',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClosedShutterView() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey.shade700,
            Colors.grey.shade800,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Shutter blade lines
          ...List.generate(5, (i) {
            final top = (i * 20.0) + 2;
            return Positioned(
              left: 0,
              right: 0,
              top: top,
              child: Container(
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
          // Center icon overlay
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveScannerView() {
    if (_cameraError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 8),
            const Text(
              'Camera Error',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _cameraError!,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _restartCamera,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: kBrandBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_cameraReady || _scannerController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kBrandBlue,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController!,
          onDetect: _onQrCodeDetected,
          errorBuilder: (context, error) {
            final msg = error.errorDetails?.message ?? 'Camera error';
            _logger.e('MobileScanner error: $msg');
            // Propagate error to state so the error card is shown consistently
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _cameraError == null) {
                setState(() => _cameraError = msg);
              }
            });
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    msg,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _restartCamera,
                    child: const Text(
                      'Tap to retry',
                      style: TextStyle(color: kBrandBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Corner brackets overlay
        Positioned(
          top: 16, left: 16,
          child: _buildCornerBracket(topLeft: true),
        ),
        Positioned(
          top: 16, right: 16,
          child: _buildCornerBracket(topRight: true),
        ),
        Positioned(
          bottom: 16, left: 16,
          child: _buildCornerBracket(bottomLeft: true),
        ),
        Positioned(
          bottom: 16, right: 16,
          child: _buildCornerBracket(bottomRight: true),
        ),
      ],
    );
  }

  Widget _buildCornerBracket({
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _CornerBracketPainter(
          topLeft: topLeft,
          topRight: topRight,
          bottomLeft: bottomLeft,
          bottomRight: bottomRight,
        ),
      ),
    );
  }

  Widget _buildDesktopScannerBody() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: double.infinity,
          color: Colors.white,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 1100,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 36,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.desktop_windows_rounded,
                                color: primary,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'QR scanner unavailable on desktop',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Use the quick actions below to keep approvals, deals, and receipts moving while scanning stays on mobile.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.grey.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                  if (_businessName != null &&
                                      _businessName!.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      _businessName!,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: primary,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _navigateToBusinessProfile,
                              icon: const Icon(Icons.person),
                              label: const Text('Business Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _desktopStatChip(
                            icon: Icons.mark_email_unread,
                            label: 'Pending deal requests',
                            value: _pendingDealRequestsCount > 99
                                ? '99+'
                                : '$_pendingDealRequestsCount',
                            color: kBrandYellow,
                          ),
                          _desktopStatChip(
                            icon: Icons.local_offer_outlined,
                            label: 'Active deals',
                            value: _discounts.length.toString(),
                            color: kBrandBlue,
                          ),
                          _desktopStatChip(
                            icon: Icons.receipt_long,
                            label: 'Receipts and approvals',
                            value: 'Desktop friendly',
                            color: kBrandGreen,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Integrated analytics snapshot on desktop
                      const TrustedPartnerAnalyticsWidget(),

                      const SizedBox(height: 24),
                      Text(
                        'Quick actions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _desktopActionButton(
                            icon: Icons.mark_email_unread,
                            label: 'Deal requests',
                            description:
                                'Review and approve member submissions',
                            onTap: _navigateToDealRequests,
                            highlight: _pendingDealRequestsCount > 0,
                            badgeCount: _pendingDealRequestsCount,
                          ),
                          _desktopActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Add deal',
                            description: 'Publish a new discount or reward',
                            onTap: _navigateToDiscountManagement,
                          ),
                          _desktopActionButton(
                            icon: Icons.verified,
                            label: 'Approved deals',
                            description: 'See what is live for members',
                            onTap: _navigateToBillApprovals,
                          ),
                          _desktopActionButton(
                            icon: Icons.receipt_long,
                            label: 'Receipts',
                            description: 'Track submitted receipts and history',
                            onTap: _navigateToBillApprovals,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.smartphone,
                                color: primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Need to scan a member QR? Switch to the mobile app for instant camera access.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade700,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _isMemberView = true),
                              style: TextButton.styleFrom(
                                foregroundColor: primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Open member view'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _desktopStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? description,
    bool highlight = false,
    int badgeCount = 0,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SizedBox(
      width: 250,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: highlight ? 8 : 3,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: highlight
                        ? primary.withValues(alpha: 0.14)
                        : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: highlight ? primary : Colors.grey.shade800,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          if (badgeCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeCount > 99 ? '99+' : '$badgeCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Open',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 16, color: primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onQrCodeDetected(BarcodeCapture capture) async {
    // Debounce multiple detections of the same QR code
    final now = DateTime.now();
    if (_lastScanTime != null && now.difference(_lastScanTime!).inSeconds < 3) {
      return; // Ignore if scanned within 3 seconds
    }
    _lastScanTime = now;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final qrData = barcode.rawValue!;
        try {
          final dynamic decoded = jsonDecode(qrData);

          if (decoded is! Map<String, dynamic>) {
            _showErrorDialog(
              'Invalid QR code: Not a Local Lekker member code.',
            );
            break;
          }

          final Map<String, dynamic> data = decoded;

          // Validate QR type
          final type = data['type'] as String?;
          if (type != 'user_qr') {
            _showErrorDialog(
              'Invalid QR code: This is not a member QR code.',
            );
            break;
          }

          final userId = data['user_id'] as String?;
          final qrName = data['name'] as String? ?? 'Unknown';
          final qrSurname = data['surname'] as String? ?? 'Unknown';

          if (userId == null || userId.isEmpty) {
            _showErrorDialog('Invalid QR code: No member ID found.');
            break;
          }

          // Show loading indicator then fetch member details
          _closeScanner();
          _showMemberDetailsPopup(
            userId: userId,
            qrName: qrName,
            qrSurname: qrSurname,
          );
        } catch (e) {
          _showErrorDialog('Invalid QR code format.');
        }
        break; // Process only the first barcode
      }
    }
  }

  /// Fetches member details from Supabase and shows a rich popup
  void _showMemberDetailsPopup({
    required String userId,
    required String qrName,
    required String qrSurname,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return _MemberDetailsSheet(
          userId: userId,
          qrName: qrName,
          qrSurname: qrSurname,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await SupabaseService.instance.signOut();
      if (!context.mounted) return;

      // Navigate to welcome page after sign out
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
        (route) => false, // Remove all previous routes
      );
    } catch (e) {
      if (!context.mounted) return;

      // Show error if sign out fails
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    }
  }
}

/// Bottom-sheet style widget that loads and displays member details from Supabase
class _MemberDetailsSheet extends StatefulWidget {
  final String userId;
  final String qrName;
  final String qrSurname;

  const _MemberDetailsSheet({
    required this.userId,
    required this.qrName,
    required this.qrSurname,
  });

  @override
  State<_MemberDetailsSheet> createState() => _MemberDetailsSheetState();
}

class _MemberDetailsSheetState extends State<_MemberDetailsSheet> {
  final Logger _logger = Logger();
  bool _isLoading = true;
  String? _error;

  // Profile data
  String _name = '';
  String _surname = '';
  String _email = '';
  String _subscriptionStatus = 'unknown';
  String? _memberSince;

  // QR validity
  bool _qrIsActive = false;
  String? _qrExpiresAt;
  bool _qrIsExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchMemberDetails();
  }

  Future<void> _fetchMemberDetails() async {
    try {
      final client = SupabaseService.instance.client;

      // Fetch profile and QR code data in parallel
      final results = await Future.wait<dynamic>([
        client
            .from('profiles')
            .select('name, surname, email, subscription, role, created_at')
            .eq('id', widget.userId)
            .maybeSingle(),
        client
            .from('user_qr_codes')
            .select('is_active, expires_at, created_at')
            .eq('user_id', widget.userId)
            .eq('is_active', true)
            .order('created_at', ascending: false)
            .limit(1),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final qrCodes = results[1] as List<dynamic>;

      if (!mounted) return;

      if (profile == null) {
        setState(() {
          _error = 'Member not found in database';
          _isLoading = false;
          // Fall back to QR data
          _name = widget.qrName;
          _surname = widget.qrSurname;
        });
        return;
      }

      // Parse profile
      _name = profile['name'] as String? ?? widget.qrName;
      _surname = profile['surname'] as String? ?? widget.qrSurname;
      _email = profile['email'] as String? ?? '';
      _subscriptionStatus = (profile['subscription'] as String? ?? 'unknown').toLowerCase();
      final createdAt = profile['created_at'] as String?;
      if (createdAt != null) {
        try {
          final dt = DateTime.parse(createdAt);
          _memberSince = '${dt.day}/${dt.month}/${dt.year}';
        } catch (_) {}
      }

      // Parse QR code validity
      if (qrCodes.isNotEmpty) {
        final qr = qrCodes[0] as Map<String, dynamic>;
        _qrIsActive = qr['is_active'] == true;
        _qrExpiresAt = qr['expires_at'] as String?;
        if (_qrExpiresAt != null) {
          try {
            final expiryDate = DateTime.parse(_qrExpiresAt!);
            _qrIsExpired = expiryDate.isBefore(DateTime.now());
            final daysLeft = expiryDate.difference(DateTime.now()).inDays;
            _qrExpiresAt = daysLeft > 0 ? '$daysLeft days' : 'Expired';
          } catch (_) {}
        }
      } else {
        _qrIsActive = false;
        _qrExpiresAt = null;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      _logger.e('Error fetching member details: $e');
      if (!mounted) return;
      setState(() {
        // Fall back to QR data on error
        _name = widget.qrName;
        _surname = widget.qrSurname;
        _isLoading = false;
        // Don't set _error - still show what we have from QR
      });
    }
  }

  bool get _isMemberActive =>
      _subscriptionStatus == 'active' && _qrIsActive && !_qrIsExpired;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: _isLoading ? _buildLoading() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 20),
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('Verifying member...', style: TextStyle(fontSize: 16, color: Colors.grey)),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildContent() {
    final statusColor = _isMemberActive ? kBrandGreen : Colors.red;
    final statusIcon = _isMemberActive ? Icons.verified : Icons.cancel;
    final statusText = _isMemberActive ? 'Active Member' : 'Inactive / Expired';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Member avatar and name
        CircleAvatar(
          radius: 36,
          backgroundColor: statusColor.withValues(alpha: 0.15),
          child: Text(
            '${_name.isNotEmpty ? _name[0].toUpperCase() : '?'}${_surname.isNotEmpty ? _surname[0].toUpperCase() : '?'}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '$_name $_surname',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),

        if (_email.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _email,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 20),

        // Details grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _detailRow(
                Icons.credit_card,
                'Subscription',
                _subscriptionStatus == 'unknown' ? 'Not verified' : _subscriptionStatus.capitalize(),
                _subscriptionStatus == 'active' ? kBrandGreen : kBrandYellow,
              ),
              const Divider(height: 20),
              _detailRow(
                Icons.qr_code,
                'QR Code',
                _qrIsActive && !_qrIsExpired ? 'Valid' : 'Invalid / Expired',
                _qrIsActive && !_qrIsExpired ? kBrandGreen : Colors.red,
              ),
              if (_qrExpiresAt != null && _qrIsActive && !_qrIsExpired) ...[
                const Divider(height: 20),
                _detailRow(
                  Icons.timer_outlined,
                  'Expires in',
                  _qrExpiresAt!,
                  kBrandBlue,
                ),
              ],
              if (_memberSince != null) ...[
                const Divider(height: 20),
                _detailRow(
                  Icons.calendar_today,
                  'Member since',
                  _memberSince!,
                  Colors.grey.shade700,
                ),
              ],
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kBrandYellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBrandYellow.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: kBrandBlue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(fontSize: 13, color: kBrandBlue),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Close button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: statusColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value, Color valueColor) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: valueColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for scanner corner brackets
class _CornerBracketPainter extends CustomPainter {
  final bool topLeft;
  final bool topRight;
  final bool bottomLeft;
  final bool bottomRight;

  _CornerBracketPainter({
    this.topLeft = false,
    this.topRight = false,
    this.bottomLeft = false,
    this.bottomRight = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBrandYellow
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final len = size.width * 0.8;

    if (topLeft) {
      canvas.drawLine(Offset.zero, Offset(len, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, len), paint);
    }
    if (topRight) {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width - len, 0), paint);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, len), paint);
    }
    if (bottomLeft) {
      canvas.drawLine(Offset(0, size.height), Offset(len, size.height), paint);
      canvas.drawLine(Offset(0, size.height), Offset(0, size.height - len), paint);
    }
    if (bottomRight) {
      canvas.drawLine(Offset(size.width, size.height), Offset(size.width - len, size.height), paint);
      canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Extension to capitalize first letter
extension _StringCapitalize on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
