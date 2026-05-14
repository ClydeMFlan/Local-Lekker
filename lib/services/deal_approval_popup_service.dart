import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification.dart';
import '../models/deal_authorization.dart';
import '../features/payments/deal_payment_webview_page.dart';
import 'notification_service.dart';
import 'navigation_service.dart';
import 'paystack_service.dart';
import 'supabase_service.dart';
import '../features/payments/pending_payments_page.dart';
import 'package:flutter/foundation.dart';

// Simple holder for payout/subaccount context used in payment confirmation
class _PayoutContext {
  _PayoutContext({
    required this.subaccountCode,
    required this.isActive,
    required this.bankName,
    required this.percentageCharge,
  });

  final String? subaccountCode;
  final bool isActive;
  final String? bankName;
  final double percentageCharge;

  bool get hasValidSubaccount =>
      subaccountCode != null && subaccountCode!.isNotEmpty && isActive;

  double platformFee(double amount) {
    final pct = percentageCharge.clamp(0, 100);
    return amount * (pct / 100);
  }

  double partnerReceives(double amount) {
    final fee = platformFee(amount);
    final net = amount - fee;
    return net < 0 ? 0 : net;
  }
}

class DealApprovalPopupService {
  static final DealApprovalPopupService _instance =
      DealApprovalPopupService._internal();
  factory DealApprovalPopupService() => _instance;
  DealApprovalPopupService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final PaystackService _paystackService = PaystackService();

  // Guard flag to prevent double-tap on payment authorization
  bool _paymentInitInProgress = false;

  // Tracks whether the payment progress overlay is currently shown so we
  // can dismiss it safely on success/error paths.
  bool _paymentProgressOpen = false;

  /// Show a full-screen, non-dismissible progress overlay while a payment
  /// is being processed. Replaces the previous SnackBar approach so that
  /// the underlying authorisation screen is fully covered until the
  /// operation completes (or fails).
  void _showPaymentProgressOverlay(
    BuildContext context, {
    required String message,
  }) {
    if (_paymentProgressOpen) return;
    _paymentProgressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      useRootNavigator: true,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait, do not close the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Dismiss the payment progress overlay if it is open.
  void _dismissPaymentProgressOverlay(BuildContext context) {
    if (!_paymentProgressOpen) return;
    _paymentProgressOpen = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Check for unread deal approval notifications and show popup if found
  Future<void> checkAndShowApprovalPopup(
    BuildContext context,
    String userId,
  ) async {
    try {
      // Get unread deal_approved notifications
      final notifications = await _notificationService.getUserNotifications(
        userId,
        unreadOnly: true,
      );

      final approvalNotifications = notifications
          .where((notif) => notif.type == 'deal_approved')
          .toList();

      if (approvalNotifications.isEmpty) return;

      // Show popup for the first unread approval
      final notification = approvalNotifications.first;
      final dealId = notification.data?['deal_authorization_id'];

      if (dealId != null && context.mounted) {
        final deal = await _getDealAuthorization(dealId);

        // Don't show popup if payment already completed
        if (deal.paymentCompletedAt != null || deal.completedAt != null) {
          if (kDebugMode) {
            print(
              '[INFO] Deal $dealId already paid/completed, marking notification as read',
            );
          }
          await _notificationService.markNotificationAsRead(notification.id);
          return;
        }

        await _showApprovalDialog(context, deal, notification.id);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ERROR] Failed to check for approval popups: $e');
      }
    }
  }

  /// Public helper to start payment for a known deal id
  Future<void> startPaymentForDeal(BuildContext context, String dealId) async {
    try {
      final deal = await _getDealAuthorization(dealId);
      await _showApprovalDialog(context, deal, 'manual_start');
    } catch (e) {
      if (kDebugMode) {
        print('[ERROR] startPaymentForDeal failed: $e');
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to start payment: $e')));
      }
    }
  }

  Future<DealAuthorization> _getDealAuthorization(String dealId) async {
    final response = await _supabase
        .from('deal_authorizations')
        .select('''
          *,
          trusted_partner_discounts (
            id,
            trusted_partner_id,
            business_id,
            name,
            description,
            item_name,
            item_price,
            percentage,
            fixed_amount,
            is_active,
            created_at,
            updated_at,
            businesses (
              name
            )
          ),
          profiles!deal_authorizations_member_id_fkey (
            id,
            name,
            surname,
            email,
            created_at,
            updated_at
          )
        ''')
        .eq('id', dealId)
        .single();

    return DealAuthorization.fromJson(response);
  }

  Future<void> _showApprovalDialog(
    BuildContext context,
    DealAuthorization deal,
    String notificationId,
  ) async {
    if (!context.mounted) return;

    final businessName = deal.businessName ?? 'Business';
    final discountName = deal.discount?.name ?? 'Deal';

    // Pre-fetch payout/subaccount context for trust signals
    final payoutContext = await _fetchPayoutContext(deal);

    await showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to dismiss
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Deal Approved!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your deal authorization at $businessName has been approved.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deal Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount:'),
                        Text(
                          discountName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Business:'),
                        Text(
                          businessName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          payoutContext.hasValidSubaccount
                              ? Icons.verified
                              : Icons.error_outline,
                          color: payoutContext.hasValidSubaccount
                              ? Colors.green
                              : Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payoutContext.hasValidSubaccount
                                    ? 'Partner banking ready'
                                    : 'Partner banking not ready',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: payoutContext.hasValidSubaccount
                                      ? Colors.green.shade800
                                      : Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                payoutContext.hasValidSubaccount
                                    ? 'Settles to ${payoutContext.bankName ?? 'linked account'}'
                                    : 'Banking details are required before you can pay.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (deal.amount != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment breakdown',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('You pay'),
                                Text('R${deal.amount!.toStringAsFixed(2)}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Partner receives'),
                                Text(
                                  'R${payoutContext.partnerReceives(deal.amount!).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Platform/processing fee'),
                                Text(
                                  'R${payoutContext.platformFee(deal.amount!).toStringAsFixed(2)}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount Due:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'R${deal.amount?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (deal.paymentMethod == 'pos')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Request approved! Please proceed to pay in-store at $businessName.',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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
                // Close dialog first
                Navigator.of(dialogContext).pop();

                // Then mark notification as read and show snackbar
                _notificationService
                    .markNotificationAsRead(notificationId)
                    .then((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Saved to Pending Payments'),
                            action: SnackBarAction(
                              label: 'Open',
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) =>
                                        const PendingPaymentsPage(),
                                  ),
                                );
                              },
                            ),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    });
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: () async {
                if (kDebugMode) {
                  print('🔴 AUTHORIZE PAYMENT BUTTON CLICKED!');
                }
                if (kDebugMode) {
                  print('🔴 Deal: ${deal.id}');
                }
                if (kDebugMode) {
                  print('🔴 Payment Method: ${deal.paymentMethod}');
                }
                if (kDebugMode) {
                  print('🔴 Amount: ${deal.amount}');
                }

                // Guard against double-tap
                if (_paymentInitInProgress) {
                  if (kDebugMode) {
                    print(
                      '⚠️ Payment initialization already in progress, ignoring tap',
                    );
                  }
                  return;
                }

                if (kDebugMode) {
                  print('✅ Guard flag check passed, proceeding...');
                }
                // Set guard flag
                _paymentInitInProgress = true;

                try {
                  // Mark notification as read (skip for manual starts)
                  if (notificationId != 'manual_start') {
                    await _notificationService.markNotificationAsRead(
                      notificationId,
                    );
                  } else {
                    if (kDebugMode) {
                      print('ℹ️ Skipping notification mark (manual start)');
                    }
                  }

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();

                    // Navigate to payment page based on payment method
                    if (deal.paymentMethod == 'in_app') {
                      // Show payment confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Confirm Payment'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You are about to pay R${deal.amount!.toStringAsFixed(2)} for $discountName.',
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.blue.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Payment will be processed by Local Lekker and transferred to $businessName.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
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
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                payoutContext.hasValidSubaccount
                                    ? 'Proceed to Payment'
                                    : 'Banking Required',
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true &&
                          payoutContext.hasValidSubaccount) {
                        // Process in-app payment via Paystack
                        await _processInAppPayment(
                          context,
                          deal,
                          businessName,
                          discountName,
                          payoutContext,
                        );
                      }
                    } else {
                      // For POS payment, show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please visit $businessName to complete your POS payment.',
                          ),
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } finally {
                  // Always reset guard flag
                  _paymentInitInProgress = false;
                }
              },
              child: Text(
                deal.paymentMethod == 'in_app'
                    ? (payoutContext.hasValidSubaccount
                          ? 'Authorize Payment'
                          : 'Partner Banking Needed')
                    : 'Acknowledge',
              ),
            ),
          ],
        );
      },
    );
  }

  /// Subscribe to real-time notifications for deal approvals
  Stream<List<NotificationModel>> subscribeToApprovalNotifications(
    String userId,
  ) {
    return _notificationService.subscribeToNotifications(userId).map((
      notifications,
    ) {
      return notifications
          .where((notif) => notif.type == 'deal_approved' && !notif.isRead)
          .toList();
    });
  }

  Future<_PayoutContext> _fetchPayoutContext(DealAuthorization deal) async {
    String? subaccountCode;
    String? bankName;
    double percentageCharge = 0.0;
    bool activeFlag = false;

    try {
      // deal.trustedPartnerId = TP user ID (NOT the business UUID)
      // deal.businessId = actual business UUID (from deal_authorizations.business_id)
      String? ownerUserId = deal.trustedPartnerId;

      // If we have the actual business UUID, use it to look up the owner
      if (deal.businessId != null && deal.businessId!.isNotEmpty) {
        final businessData = await Supabase.instance.client
            .from('businesses')
            .select('owner_member_id')
            .eq('id', deal.businessId!)
            .maybeSingle();
        if (businessData != null) {
          ownerUserId = businessData['owner_member_id'] as String? ?? ownerUserId;
        }
      }

      if (kDebugMode) {
        print('🔍 _fetchPayoutContext: trustedPartnerId=${deal.trustedPartnerId}, businessId=${deal.businessId}, ownerUserId=$ownerUserId');
      }

      // Try to read bank accounts (may fail silently due to RLS if member can't read TP data)
      Map<String, dynamic>? bankingData;
      try {
        bankingData = await Supabase.instance.client
            .from('trusted_partner_bank_accounts')
            .select(
              'subaccount_code, subaccount_active, is_active, bank_name, percentage_charge, updated_at',
            )
            .eq('user_id', ownerUserId!)
            .eq('is_active', true)
            .maybeSingle();

        bankingData ??= await Supabase.instance.client
              .from('trusted_partner_bank_accounts')
              .select(
                'subaccount_code, subaccount_active, is_active, bank_name, percentage_charge, updated_at',
              )
              .eq('user_id', ownerUserId)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Bank accounts query failed (likely RLS): $e');
        }
        // RLS may block member from reading TP bank accounts - continue to fallbacks
      }

      if (bankingData != null) {
        subaccountCode = (bankingData['subaccount_code'] as String?)?.trim();
        bankName = bankingData['bank_name'] as String?;
        percentageCharge =
            (bankingData['percentage_charge'] as num?)?.toDouble() ?? 0.0;
        final active = bankingData['subaccount_active'];
        final isActiveRecord = bankingData['is_active'] == true;
        activeFlag = (active == null || active == true) && isActiveRecord;
      }

      // Fallback 1: Check trusted_partners table for legacy subaccount codes
      if (subaccountCode == null || subaccountCode.isEmpty) {
        try {
          // Build OR filter using the TP user ID and the actual business UUID
          final orFilter = deal.businessId != null && deal.businessId!.isNotEmpty
              ? 'owner_member_id.eq.$ownerUserId,business_id.eq.${deal.businessId}'
              : 'owner_member_id.eq.$ownerUserId';

          final legacy = await Supabase.instance.client
              .from('trusted_partners')
              .select('paystack_subaccount_code, paystack_subaccount_id')
              .or(orFilter)
              .maybeSingle();

          final legacyCode1 = (legacy?['paystack_subaccount_code'] as String?)
              ?.trim();
          final legacyCode2 = (legacy?['paystack_subaccount_id'] as String?)
              ?.trim();
          subaccountCode = (legacyCode1 != null && legacyCode1.isNotEmpty)
              ? legacyCode1
              : (legacyCode2 ?? '');
          if (subaccountCode.isNotEmpty) {
            activeFlag = true;
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Legacy trusted_partners query failed: $e');
          }
        }
      }

      // Fallback 2: Try to get subaccount code from the discount's business data
      // (already joined in _getDealAuthorization via trusted_partner_discounts.businesses)
      if (subaccountCode == null || subaccountCode.isEmpty) {
        try {
          // Query the business's paystack_subaccount_code if stored on the business
          final bizId = deal.businessId;
          if (bizId != null && bizId.isNotEmpty) {
            final bizData = await Supabase.instance.client
                .from('businesses')
                .select('paystack_subaccount_code')
                .eq('id', bizId)
                .maybeSingle();
            final bizSubCode = (bizData?['paystack_subaccount_code'] as String?)?.trim();
            if (bizSubCode != null && bizSubCode.isNotEmpty) {
              subaccountCode = bizSubCode;
              activeFlag = true;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Business subaccount query failed: $e');
          }
        }
      }

      // If we have a subaccount code, verify it with Paystack API directly
      if (subaccountCode != null && subaccountCode.isNotEmpty) {
        try {
          final subaccountDetails = await _paystackService.getSubaccount(
            subaccountCode,
          );
          if (subaccountDetails != null) {
            bankName ??= subaccountDetails['settlement_bank'] as String?;
            if (subaccountDetails['percentage_charge'] != null) {
              percentageCharge =
                  (subaccountDetails['percentage_charge'] as num?)?.toDouble() ??
                  percentageCharge;
            }
            // Trust the Paystack API response for active status
            final paystackActive = subaccountDetails['active'];
            if (paystackActive == true) {
              activeFlag = true;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Paystack getSubaccount failed: $e');
          }
        }
      }

      if (kDebugMode) {
        print('🔍 _fetchPayoutContext result: subaccountCode=$subaccountCode, active=$activeFlag, bank=$bankName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Payout context fetch failed: $e');
      }
    }

    return _PayoutContext(
      subaccountCode: subaccountCode,
      isActive: activeFlag,
      bankName: bankName,
      percentageCharge: percentageCharge,
    );
  }

  /// Process in-app payment via Paystack
  Future<void> _processInAppPayment(
    BuildContext context,
    DealAuthorization deal,
    String businessName,
    String discountName,
    _PayoutContext payoutContext,
  ) async {
    try {
      if (kDebugMode) {
        print('💳 ========================================');
      }
      if (kDebugMode) {
        print('💳 STARTING IN-APP PAYMENT PROCESS');
      }
      if (kDebugMode) {
        print('💳 Deal ID: ${deal.id}');
      }
      if (kDebugMode) {
        print('💳 Deal Amount: ${deal.amount}');
      }
      if (kDebugMode) {
        print('💳 Business: $businessName');
      }
      if (kDebugMode) {
        print('💳 Discount: $discountName');
      }
      if (kDebugMode) {
        print('💳 Payment Method: ${deal.paymentMethod}');
      }
      if (kDebugMode) {
        print('💳 ========================================');
      }

      // Get current user
      final user = SupabaseService.instance.getCurrentUser();
      if (kDebugMode) {
        print('💳 Current User: ${user?.id}');
      }
      if (kDebugMode) {
        print('💳 User Email: ${user?.email}');
      }

      if (user == null || user.email == null) {
        if (kDebugMode) {
          print('❌ ERROR: User or email is null!');
        }
        throw Exception('User email is required for payment');
      }

      if (deal.amount == null || deal.amount! <= 0) {
        if (kDebugMode) {
          print('❌ ERROR: Deal amount is invalid: ${deal.amount}');
        }
        throw Exception('Deal amount must be greater than 0');
      }

      // All members now use Paystack payments
      if (kDebugMode) {
        print('💳 Processing as Paystack payment...');
      }
      await _processPaystackPayment(
        context,
        deal,
        businessName,
        discountName,
        user,
        payoutContext,
      );

      if (kDebugMode) {
        print('💳 ========================================');
      }
      if (kDebugMode) {
        print('💳 IN-APP PAYMENT PROCESS COMPLETED');
      }
      if (kDebugMode) {
        print('💳 ========================================');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ========================================');
      }
      if (kDebugMode) {
        print('❌ ERROR PROCESSING IN-APP PAYMENT');
      }
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      if (kDebugMode) {
        print('❌ Stack Trace: $stackTrace');
      }
      if (kDebugMode) {
        print('❌ ========================================');
      }

      if (context.mounted) {
        _dismissPaymentProgressOverlay(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _processPaystackPayment(
    BuildContext context,
    DealAuthorization deal,
    String businessName,
    String discountName,
    User user,
    _PayoutContext payoutContext,
  ) async {
    final subaccountCode = payoutContext.subaccountCode;

    // Block payment if no active subaccount is available
    if (!payoutContext.hasValidSubaccount) {
      throw Exception(
        'This business has no active Paystack subaccount yet. Please ask them to upload banking details before paying.',
      );
    }

    // Try charging the member's saved card first for instant payment
    final savedMethods = await _paystackService.getSavedPaymentMethods(user.id);

    if (savedMethods.isNotEmpty) {
      // Show card selection + CVV dialog
      if (!context.mounted) return;
      final selection = await _showCardSelectionDialog(
        context,
        savedMethods: savedMethods,
      );

      if (selection == null) {
        // Member cancelled — do nothing
        return;
      }

      if (selection['use_new_card'] == true) {
        // Member wants to add a new card — fall through to WebView
        if (kDebugMode) {
          print('💳 Member chose to use a new card, opening WebView');
        }
      } else {
        // Member selected a saved card and confirmed CVV
        final selectedAuthCode = selection['authorization_code'] as String;

      if (context.mounted) {
        _showPaymentProgressOverlay(
          context,
          message: 'Processing payment…',
        );
      }

      if (kDebugMode) {
        print('💳 Attempting saved card charge for deal ${deal.id}');
      }

      final chargeResult = await _paystackService.chargeSavedCard(
        authorizationCode: selectedAuthCode,
        amount: deal.amount!,
        userId: user.id,
        userEmail: user.email!,
        paymentType: 'one_time_payment',
        subaccountCode: subaccountCode,
        extraMetadata: {'deal_authorization_id': deal.id},
      );

      if (chargeResult == 'success') {
        if (kDebugMode) {
          print('✅ Saved card charge successful for deal ${deal.id}');
        }

        // Update deal authorization status to 'completed' directly
        try {
          final now = DateTime.now().toUtc().toIso8601String();
          final updateResponse = await SupabaseService.instance.client
              .from('deal_authorizations')
              .update({
                'status': 'completed',
                'payment_completed_at': now,
                'completed_at': now,
                'updated_at': now,
              })
              .eq('id', deal.id)
              .select();

          if (updateResponse.isEmpty) {
            if (kDebugMode) {
              print('⚠️ Deal status update returned empty - RLS may have blocked it');
            }
          } else {
            if (kDebugMode) {
              print('✅ Deal authorization ${deal.id} marked as completed');
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to update deal status: $e');
          }
          // Payment was taken — webhook will handle as fallback
        }

        // Defensive: ensure ALL unread deal_approved notifications for this
        // deal are marked read so the realtime listener on members_home_page
        // doesn't re-trigger checkAndShowApprovalPopup for a deal that has
        // just been paid (root cause of the popup re-appearing after a
        // successful in-app payment).
        try {
          await SupabaseService.instance.client
              .from('notifications')
              .update({'is_read': true})
              .eq('user_id', user.id)
              .eq('is_read', false)
              .inFilter('type', ['deal_approved', 'pos_deal_approved'])
              .filter('data->>deal_authorization_id', 'eq', deal.id);
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to mark deal_approved notifications as read: $e');
          }
        }

        // Generate receipt for saved card payment
        await _generateReceiptForSavedCardPayment(
          dealId: deal.id,
          businessName: businessName,
          discountName: discountName,
        );

        if (context.mounted) {
          _dismissPaymentProgressOverlay(context);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        // Navigate to home so the members_home_page rebuilds with fresh
        // state (subscriptions, pending payments, notification stream).
        // Without this, the user stays on the original screen whose
        // realtime notification subscription may re-trigger the
        // "Deal Approved" popup before the just-marked-read state
        // has propagated through the stream.
        if (context.mounted) {
          await NavigationService().navigateToHomeAfterPayment(context);
        }
        return;
      }

      // Saved card charge failed — fall through to WebView
      if (kDebugMode) {
        print('⚠️ Saved card charge failed, falling back to WebView');
      }
      if (context.mounted) {
        _dismissPaymentProgressOverlay(context);
        ScaffoldMessenger.of(context).clearSnackBars();
      }
      } // end of saved card selection block
    }

    // No saved card or charge failed — open Paystack WebView checkout
    if (context.mounted) {
      _showPaymentProgressOverlay(
        context,
        message: 'Initializing payment…',
      );
    }

    if (kDebugMode) {
      print('💳 Calling Paystack service...');
    }
    final paymentResult = await _paystackService.startOneTimePayment(
      itemName: '$discountName at $businessName',
      itemDescription: 'Payment to $businessName for $discountName',
      amount: deal.amount!,
      userId: user.id,
      userEmail: user.email!,
      subaccountCode: subaccountCode,
      businessName: businessName,
      extraMetadata: {'deal_authorization_id': deal.id},
    );

    final authorizationUrl = paymentResult?['authorization_url'];
    final transactionReference = paymentResult?['reference'];

    if (authorizationUrl == null) {
      if (context.mounted) {
        _dismissPaymentProgressOverlay(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize payment. Please try again.'),
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      _dismissPaymentProgressOverlay(context);
      if (kDebugMode) {
        print('💳 Opening DealPaymentWebViewPage...');
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DealPaymentWebViewPage(
            authorizationUrl: authorizationUrl,
            dealId: deal.id,
            transactionReference: transactionReference,
          ),
        ),
      );
    }
  }

  /// Shows a dialog letting the member select from saved cards or add a new one.
  /// If a saved card is selected, prompts for CVV.
  /// Returns:
  ///   - {'authorization_code': '...', 'use_new_card': false} if saved card selected + CVV confirmed
  ///   - {'use_new_card': true} if member wants to add a new card
  ///   - null if cancelled
  Future<Map<String, dynamic>?> _showCardSelectionDialog(
    BuildContext context, {
    required List<Map<String, dynamic>> savedMethods,
  }) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _CardSelectionDialog(savedMethods: savedMethods);
      },
    );

    return result;
  }

  /// Generate receipts after a successful saved card payment.
  /// Creates entries in both virtual_receipts (member) and deal_receipts (TP)
  /// and sends notifications to both parties.
  Future<void> _generateReceiptForSavedCardPayment({
    required String dealId,
    required String businessName,
    required String discountName,
  }) async {
    try {
      if (kDebugMode) {
        print('🧾 Generating receipt for saved card payment, deal: $dealId');
      }

      // Fetch deal authorization with joined data
      final dealResponse = await _supabase
          .from('deal_authorizations')
          .select('''
            *,
            trusted_partner_discounts(
              *,
              businesses(*)
            ),
            profiles(*)
          ''')
          .eq('id', dealId)
          .single();

      final dealData = dealResponse;
      final discountData = dealData['trusted_partner_discounts'];
      final businessData = discountData?['businesses'];
      final memberData = dealData['profiles'];
      final businessId =
          discountData?['business_id'] as String? ??
          dealData['business_id'] as String?;
      final trustedPartnerId =
          discountData?['trusted_partner_id'] as String? ??
          businessData?['owner_member_id'] as String?;

      if (businessId == null) {
        if (kDebugMode) {
          print('❌ Cannot generate receipt: business_id is null');
        }
        return;
      }

      // Generate sequential receipt number
      String receiptNumber;
      try {
        final result = await _supabase.rpc(
          'get_next_receipt_number',
          params: {'p_business_id': businessId},
        );
        receiptNumber = result as String;
      } catch (e) {
        receiptNumber = 'RCP-${DateTime.now().millisecondsSinceEpoch}';
        if (kDebugMode) {
          print('⚠️ Sequential numbering failed, using fallback: $receiptNumber');
        }
      }

      final qrCode = 'RECEIPT:$dealId:$receiptNumber';

      final receiptData = {
        'receipt_number': receiptNumber,
        'deal_authorization_id': dealId,
        'business_name': businessData?['name'] ?? businessName,
        'business_id': businessId,
        'member_name':
            '${memberData?['name'] ?? 'Unknown'} ${memberData?['surname'] ?? 'Member'}',
        'member_email': memberData?['email'] ?? 'N/A',
        'discount_name': discountData?['name'] ?? discountName,
        'amount': dealData['amount'] ?? 0.0,
        'payment_method': 'saved_card',
        'transaction_date': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
      };

      // Insert into virtual_receipts table (member receipt)
      await _supabase.from('virtual_receipts').insert({
        'deal_authorization_id': dealId,
        'receipt_number': receiptNumber,
        'receipt_data': receiptData,
        'qr_code': qrCode,
      }).select().single();

      if (kDebugMode) {
        print('✅ Virtual receipt created: $receiptNumber');
      }

      // Insert into deal_receipts table (trusted partner receipt)
      await _supabase.from('deal_receipts').insert({
        'member_id': memberData?['id'],
        'trusted_partner_id': trustedPartnerId,
        'business_id': businessId,
        'deal_authorization_id': dealId,
        'receipt_number': receiptNumber,
        'amount': dealData['amount'],
        'business_name': businessData?['name'] ?? businessName,
        'discount_name': discountData?['name'] ?? discountName,
        'member_name':
            '${memberData?['name'] ?? 'Unknown'} ${memberData?['surname'] ?? 'Member'}',
        'member_email': memberData?['email'],
        'payment_method': 'saved_card',
      });

      if (kDebugMode) {
        print('✅ Deal receipt created: $receiptNumber');
      }

      // Send notifications to both parties
      if (trustedPartnerId != null) {
        try {
          final memberName =
              '${memberData?['name'] ?? 'Unknown'} ${memberData?['surname'] ?? 'Member'}';
          final bName = businessData?['name'] ?? businessName;
          final dName = discountData?['name'] ?? discountName;
          final amount = (dealData['amount'] as num?)?.toDouble() ?? 0.0;

          await _notificationService.notifyTrustedPartnerOfPayment(
            trustedPartnerId: trustedPartnerId,
            dealAuthorizationId: dealId,
            memberId: memberData?['id'] ?? '',
            memberName: memberName,
            dealName: dName,
            amount: amount,
            receiptNumber: receiptNumber,
            businessName: bName,
          );

          final currentUserId = _supabase.auth.currentUser?.id;
          if (currentUserId != null) {
            await _notificationService.notifyMemberOfPaymentSuccess(
              memberId: currentUserId,
              dealAuthorizationId: dealId,
              businessName: bName,
              dealName: dName,
              amount: amount,
              receiptNumber: receiptNumber,
            );
          }

          if (kDebugMode) {
            print('✅ Payment notifications sent');
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ Failed to send notifications: $e');
          }
        }
      }

      if (kDebugMode) {
        print('🧾 ✅ Receipt generation complete: $receiptNumber');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Receipt generation failed: $e');
      }
      // Don't rethrow — payment was successful, receipt failure shouldn't block the user
    }
  }
}

/// Stateful dialog for card selection + CVV entry
class _CardSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> savedMethods;

  const _CardSelectionDialog({required this.savedMethods});

  @override
  State<_CardSelectionDialog> createState() => _CardSelectionDialogState();
}

class _CardSelectionDialogState extends State<_CardSelectionDialog> {
  late String? _selectedAuthCode;
  bool _showCvvInput = false;
  final _cvvController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-select primary card, or first card
    final primary = widget.savedMethods.where((m) => m['is_primary'] == true);
    if (primary.isNotEmpty) {
      _selectedAuthCode = primary.first['authorization_code'];
    } else {
      _selectedAuthCode = widget.savedMethods.first['authorization_code'];
    }
  }

  @override
  void dispose() {
    _cvvController.dispose();
    super.dispose();
  }

  IconData _getCardIcon(String cardType) {
    final type = cardType.toLowerCase();
    if (type.contains('visa')) return Icons.credit_card;
    if (type.contains('master')) return Icons.credit_card;
    return Icons.credit_card;
  }

  @override
  Widget build(BuildContext context) {
    if (_showCvvInput) {
      return _buildCvvScreen(context);
    }
    return _buildCardSelectionScreen(context);
  }

  Widget _buildCardSelectionScreen(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Payment Card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a card for this payment:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...widget.savedMethods.map((method) {
              final authCode = method['authorization_code'] as String;
              final cardType = method['card_type'] ?? 'Card';
              final last4 = method['last4'] ?? '****';
              final bank = method['bank'] ?? '';
              final isPrimary = method['is_primary'] == true;
              final isSelected = _selectedAuthCode == authCode;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selectedAuthCode = authCode),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _getCardIcon(cardType),
                          color: Colors.grey.shade700,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$cardType •••• $last4',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (bank.isNotEmpty)
                                Text(
                                  bank,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isPrimary)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Primary',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            // Add new card option
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).pop({'use_new_card': true});
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).primaryColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Use a different card',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedAuthCode != null
              ? () => setState(() => _showCvvInput = true)
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildCvvScreen(BuildContext context) {
    final selectedCard = widget.savedMethods.firstWhere(
      (m) => m['authorization_code'] == _selectedAuthCode,
    );
    final cardType = selectedCard['card_type'] ?? 'Card';
    final last4 = selectedCard['last4'] ?? '****';

    return AlertDialog(
      title: const Text('Enter CVV'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.credit_card,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '$cardType •••• $last4',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'For your security, please enter the CVV from the back of your card.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cvvController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'CVV',
                hintText: 'Enter CVV',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                counterText: '',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'CVV is required';
                }
                if (!RegExp(r'^\d{3,4}$').hasMatch(value)) {
                  return 'Enter a valid 3 or 4 digit CVV';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _showCvvInput = false;
            _cvvController.clear();
          }),
          child: const Text('Back'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop({
                'authorization_code': _selectedAuthCode,
                'use_new_card': false,
              });
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
