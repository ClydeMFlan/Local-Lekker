import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:io' show Platform;
import 'dart:convert';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/discount_service.dart';
import '../../models/discount.dart';
import 'welcome_page.dart';
import 'merchant_profile_page.dart';
import 'discount_selection_page.dart';
import '../business/bill_approval_page.dart';
import 'business_bill_scanner_dialog.dart';

class TrustedPartnerHomePage extends StatefulWidget {
  const TrustedPartnerHomePage({super.key});

  @override
  State<TrustedPartnerHomePage> createState() => _TrustedPartnerHomePageState();
}

class _TrustedPartnerHomePageState extends State<TrustedPartnerHomePage> {
  bool _isDarkMode = false;
  final MobileScannerController _scannerController = MobileScannerController();
  final DiscountService _discountService = DiscountService();
  List<Discount> _discounts = [];
  bool _discountsLoading = true;
  DateTime? _lastScanTime;
  String? _businessName;
  final Logger _logger = Logger();

  // Check if we're on a mobile platform that supports camera
  bool get _isMobilePlatform => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
    _loadBusinessName();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        title: Image.asset('assets/locallekker_logo.png', height: 200),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
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
                  title: Text('Merchant Profile'),
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
            ],
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          IconButton(
            tooltip: 'Sign Out',
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _isMobilePlatform
          ? _buildMobileScannerBody()
          : _buildDesktopScannerBody(),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'approvals':
        _navigateToBillApprovals();
        break;
      case 'scan_bills':
        _scanBusinessBills();
        break;
      case 'profile':
        _navigateToMerchantProfile();
        break;
      case 'theme':
        _toggleTheme();
        break;
    }
  }

  void _navigateToMerchantProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MerchantProfilePage()),
    );
  }

  void _navigateToBillApprovals() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BillApprovalPage()),
    );
  }

  Future<void> _scanBusinessBills() async {
    try {
      // Get current user
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in first')));
        return;
      }

      // Get business information
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('id, name')
          .eq('owner_member_id', user.id)
          .single();

      final businessId = businessResponse['id']?.toString();
      final businessName = businessResponse['name']?.toString() ?? '';

      if (businessId == null || businessId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Business profile not found. Please complete your business setup first.',
            ),
          ),
        );
        return;
      }

      if (businessName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Business name not found. Please update your business profile.',
            ),
          ),
        );
        return;
      }

      // Open the business bill scanner dialog
      await showDialog(
        context: context,
        builder: (context) => BusinessBillScannerDialog(
          businessId: businessId,
          businessName: businessName,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error opening scanner: $e')));
    }
  }

  void _navigateToDiscountSelection(String name, String surname) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DiscountSelectionPage(userName: name, userSurname: surname),
      ),
    );
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
      _logger.e('Failed to load discounts: $e');
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
            .select('name')
            .eq('owner_member_id', user.id)
            .maybeSingle();
        if (business != null) {
          setState(() => _businessName = business['name']);
        }
      }
    } catch (e) {
      _logger.e('Failed to load business name: $e');
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
            percentage: discount.percentage,
            fixedAmount: discount.fixedAmount,
            isActive: !discount.isActive,
            createdAt: discount.createdAt,
            updatedAt: DateTime.now(),
          );
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Discount ${discount.isActive ? 'deactivated' : 'activated'}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update discount status'),
          duration: Duration(seconds: 2),
        ),
      );
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
                onPressed: null, // Discount management not available in REV_01
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
                  onPressed:
                      null, // Discount management not available in REV_01
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._discounts
                .take(3)
                .map(
                  (discount) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            discount.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              discount.discountDisplay,
                              style: TextStyle(
                                color: discount.isActive
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: discount.isActive,
                              onChanged: (value) =>
                                  _toggleDiscountActive(discount),
                              activeThumbColor: Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            if (_discounts.length > 3)
              Text(
                '+${_discounts.length - 3} more',
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileScannerBody() {
    return Column(
      children: [
        // Business Name
        if (_businessName != null && _businessName!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _businessName!,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),

        // QR Scanner Section - 200x200 square viewer
        Container(
          height: 200, // 200x200 square viewer
          width: 200,
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onQrCodeDetected,
            ),
          ),
        ),

        // Instructions and Status
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Icon(Icons.qr_code_scanner, size: 48, color: Colors.blue),
              const SizedBox(height: 16),
              const Text(
                'Scan Member QR Code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Point your camera at a member\'s QR code to process their information',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Discount Summary Section
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            child: _buildDiscountSummary(),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopScannerBody() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'QR Scanner Unavailable',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera scanning is only available on mobile devices (Android/iOS).\n\n'
            'On desktop, you can still access merchant features through the menu.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToMerchantProfile,
            icon: const Icon(Icons.person),
            label: const Text('Merchant Profile'),
          ),
        ],
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
          // Parse QR data as JSON
          final Map<String, dynamic> data = jsonDecode(qrData);
          final name = data['name'] as String? ?? 'Unknown';
          final surname = data['surname'] as String? ?? 'Unknown';
          _showUserDialog(name, surname);
        } catch (e) {
          _showErrorDialog('Invalid QR code format: $e');
        }
        break; // Process only the first barcode
      }
    }
  }

  void _showUserDialog(String name, String surname) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent, // Remove black fade background
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  'User Scanned',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Name: $name\nSurname: $surname',
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(
                            context,
                          ).pop(); // Close the current dialog
                          _navigateToDiscountSelection(name, surname);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Apply Discount'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
