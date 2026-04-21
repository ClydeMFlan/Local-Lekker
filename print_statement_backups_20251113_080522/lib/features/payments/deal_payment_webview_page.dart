import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_lekker/services/navigation_service.dart';
import 'package:local_lekker/services/paystack_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class DealPaymentWebViewPage extends StatefulWidget {
  final String authorizationUrl;
  final String dealId;

  const DealPaymentWebViewPage({
    super.key,
    required this.authorizationUrl,
    required this.dealId,
  });

  @override
  State<DealPaymentWebViewPage> createState() => _DealPaymentWebViewPageState();
}

class _DealPaymentWebViewPageState extends State<DealPaymentWebViewPage> {
  final Logger _logger = Logger();
  final SupabaseClient _supabase = Supabase.instance.client;
  late final WebViewController _controller;
  bool _loading = true;
  bool _processingPayment = false;
  bool _showingSuccess = false;
  bool _receiptGenerated = false; // Track if receipt already generated
  bool _generatingReceipt =
      false; // Track if generating receipt from manual button
  bool _paymentVerified =
      false; // True only after Paystack verification or success handler
  Timer? _successCheckTimer;

  String get _callbackUrl {
    final webCallbackUrl = dotenv.env['PAYSTACK_CALLBACK_URL'];
    return webCallbackUrl ?? 'locallekker://payment/callback';
  }

  bool _isPaystackSuccessUrl(String url) {
    final isPaystackUrl =
        url.contains('checkout.paystack.com') || url.contains('paystack.com');
    final hasSuccessIndicator =
        url.contains('success') ||
        url.contains('trxref=') ||
        url.contains('reference=') ||
        url.contains('/receipt') ||
        url.contains('status=success') ||
        url.contains('payment-successful') ||
        url.contains('transaction-successful') ||
        url.toLowerCase().contains('payment%20successful') ||
        url.toLowerCase().contains('you%20paid');

    _logger.d(
      'URL Check - isPaystackUrl: $isPaystackUrl, hasSuccess: $hasSuccessIndicator, url: $url',
    );

    return isPaystackUrl && hasSuccessIndicator;
  }

  String? _extractReferenceFromUrl(String url) {
    try {
      final uri = Uri.parse(url);

      // Try multiple query parameter names
      String? reference =
          uri.queryParameters['reference'] ??
          uri.queryParameters['trxref'] ??
          uri.queryParameters['tx_ref'] ??
          uri.queryParameters['transaction_reference'] ??
          uri.queryParameters['ref'];

      if (reference == null || reference.isEmpty) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) reference = segments.last;
      }

      _logger.d('Extracted reference from URL: $reference (from: $url)');
      return (reference != null && reference.isNotEmpty) ? reference : null;
    } catch (e) {
      _logger.w('Failed to parse reference from URL: $e');
      return null;
    }
  }

  // New: Extract reference from page JavaScript if not in URL
  Future<String?> _extractReferenceFromPage() async {
    try {
      // Try to extract transaction reference from page's JavaScript variables
      final jsExtractScript = '''
        (function() {
          // Common variable names Paystack might use
          if (typeof trxref !== 'undefined') return trxref;
          if (typeof reference !== 'undefined') return reference;
          if (typeof transaction_reference !== 'undefined') return transaction_reference;
          
          // Check window object
          if (window.trxref) return window.trxref;
          if (window.reference) return window.reference;
          if (window.transaction_reference) return window.transaction_reference;
          
          // Try to extract from page text as last resort
          const text = document.body.innerText;
          const refMatch = text.match(/reference[:\\s]+([A-Za-z0-9_-]+)/i);
          if (refMatch && refMatch[1]) return refMatch[1];
          
          return null;
        })()
      ''';

      final result = await _controller.runJavaScriptReturningResult(
        jsExtractScript,
      );

      if (result.toString().isNotEmpty) {
        final ref = result.toString();
        if (ref != 'null') {
          _logger.i('✅ Extracted reference from page JavaScript: $ref');
          return ref;
        }
      }
    } catch (e) {
      _logger.w('Failed to extract reference from page: $e');
    }
    return null;
  }

  Future<void> _handlePaymentSuccess({String? url}) async {
    if (_processingPayment) {
      _logger.w('⚠️ Payment already being processed, ignoring duplicate call');
      return; // Prevent multiple calls
    }

    _successCheckTimer?.cancel(); // Stop polling

    // IMMEDIATELY show success overlay - don't wait for async operations
    if (mounted) {
      setState(() {
        _processingPayment = true;
        _showingSuccess = true;
        _paymentVerified = true; // Mark verified through success pathway
      });
    }

    print('✅ ========================================');
    print('✅ DEAL PAYMENT SUCCESS');
    print('✅ Deal ID: ${widget.dealId}');
    _logger.i('=== DEAL PAYMENT SUCCESS HANDLER CALLED ===');

    _logger.i('Deal payment completed for deal: ${widget.dealId}');

    // Before updating local DB, try to verify Paystack transaction to
    // capture authorization_code and customer_code for future CVV-only flows
    try {
      if (url != null) {
        final ref = _extractReferenceFromUrl(url);
        if (ref != null) {
          final paystack = PaystackService();
          final details = await paystack.verifyTransaction(ref);
          if (details != null) {
            final auth = details['authorization'];
            final customer = details['customer'];
            // Save authorization_code to members_card_details (idempotent-ish)
            if (auth != null) {
              final code = auth['authorization_code'];
              if (code != null && code.toString().isNotEmpty) {
                try {
                  // We need the current user id to save card for member
                  final uid = _supabase.auth.currentUser?.id;
                  if (uid != null) {
                    final existing = await PaystackService()
                        .getSavedPaymentMethods(uid);
                    final shouldSetPrimary =
                        existing.isEmpty ||
                        !existing.any((m) => m['is_primary'] == true);
                    await PaystackService().addPaymentMethod(uid, code, {
                      'card_type': auth['card_type'] ?? 'card',
                      'last4': auth['last4'] ?? '****',
                      'exp_month': auth['exp_month'],
                      'exp_year': auth['exp_year'],
                      'bank': auth['bank'],
                      'brand': auth['brand'],
                      'is_primary': shouldSetPrimary,
                    });
                    if (shouldSetPrimary) {
                      await PaystackService().setPrimaryPaymentMethod(
                        uid,
                        code,
                      );
                    }
                  }
                } catch (e) {
                  _logger.w('Failed to save authorization_code: $e');
                }
              }
            }
            // Save customer_code on profile to enable saved card UI
            if (customer != null) {
              final customerCode = customer['customer_code'] as String?;
              final uid = _supabase.auth.currentUser?.id;
              if (uid != null &&
                  customerCode != null &&
                  customerCode.isNotEmpty) {
                try {
                  await PaystackService().savePaystackCustomerCode(
                    userId: uid,
                    customerCode: customerCode,
                  );
                } catch (e) {
                  _logger.w('Failed to save customer_code: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      _logger.w('Verification for saving card/customer skipped/failed: $e');
    }

    // Update deal authorization with payment timestamp
    // NOTE: Keep status as 'approved' - trusted partner will move to 'completed' when issuing receipt
    try {
      // First, get current user to verify authentication
      final currentUser = _supabase.auth.currentUser;
      _logger.i('🔐 Current authenticated user: ${currentUser?.id}');
      _logger.i('🔐 User email: ${currentUser?.email}');

      final now = DateTime.now().toUtc().toIso8601String();
      _logger.i(
        '💰 Updating payment_completed_at and completed_at for deal: ${widget.dealId}',
      );
      _logger.i('💰 Setting timestamps to: $now (UTC)');

      print('🔐 ========================================');
      print('🔐 AUTHENTICATION CHECK');
      print('🔐 User ID: ${currentUser?.id}');
      print('🔐 User Email: ${currentUser?.email}');
      print('🔐 Deal ID: ${widget.dealId}');
      print('🔐 ========================================');

      final response = await _supabase
          .from('deal_authorizations')
          .update({
            'payment_completed_at': now,
            'completed_at': now, // Also update completed_at
            'updated_at': now,
          })
          .eq('id', widget.dealId)
          .select();

      print('💰 ========================================');
      print('💰 RAW UPDATE RESPONSE: $response');
      print('💰 Response type: ${response.runtimeType}');
      print('💰 Response is empty: ${response.isEmpty}');
      print('💰 Response length: ${response.length}');
      print('💰 ========================================');

      if (response.isEmpty) {
        _logger.e('⚠️ UPDATE RETURNED EMPTY - RLS POLICY BLOCKING?');
        print('⚠️ ========================================');
        print('⚠️ UPDATE RETURNED EMPTY RESPONSE');
        print('⚠️ This usually means RLS policy blocked the update');
        print('⚠️ User ${currentUser?.id} cannot update deal ${widget.dealId}');
        print('⚠️ ========================================');
        throw Exception('Update blocked by RLS policy - no rows affected');
      }

      _logger.i('✅ Deal authorization updated with payment timestamp');
      _logger.i('✅ Update response: $response');

      print('💰 ========================================');
      print('💰 PAYMENT TIMESTAMP UPDATE SUCCESSFUL');
      print('💰 Deal ID: ${widget.dealId}');
      print('💰 payment_completed_at: $now');
      print('💰 Response: $response');
      print('💰 ========================================');

      // Auto-generate receipt after payment success
      await _autoGenerateReceipt();

      // After receipt is generated, navigate member back home automatically
      if (mounted) {
        _logger.i('Auto navigating to Members Home after successful payment');
        await Future.delayed(const Duration(milliseconds: 500));
        await NavigationService().navigateToHomeAfterPayment(context);
      }
    } catch (e) {
      _logger.e('❌ Error updating deal authorization: $e');
      print('❌ ========================================');
      print('❌ PAYMENT TIMESTAMP UPDATE FAILED');
      print('❌ Deal ID: ${widget.dealId}');
      print('❌ Error: $e');
      print('❌ ========================================');
    }

    // We now auto-navigate after receipt creation; keep UI state for safety
    _logger.i('Payment processed; auto-navigation initiated');
  }

  Future<void> _autoGenerateReceipt() async {
    // Prevent duplicate receipt generation
    if (_receiptGenerated) {
      _logger.i('🧾 Receipt already generated, skipping duplicate generation');
      print('🧾 Receipt already generated, skipping duplicate generation');
      return;
    }

    try {
      _receiptGenerated = true; // Mark as generated at start

      _logger.i('🧾 ========================================');
      _logger.i('🧾 AUTO-GENERATE RECEIPT START');
      _logger.i('🧾 Deal ID: ${widget.dealId}');
      _logger.i('🧾 ========================================');

      print('🧾 ========================================');
      print('🧾 AUTO-GENERATE RECEIPT START');
      print('🧾 Deal ID: ${widget.dealId}');
      print('🧾 Current User: ${_supabase.auth.currentUser?.id}');
      print('🧾 ========================================');

      // Get deal authorization data with all necessary joins
      _logger.i('🧾 Step 1: Fetching deal authorization data...');
      print('🧾 Step 1: Fetching deal authorization data...');

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
          .eq('id', widget.dealId)
          .single();

      _logger.i('🧾 Step 2: Deal data fetched successfully');
      print('🧾 ✅ Step 2: Deal data fetched successfully');
      print('🧾 Deal response keys: ${dealResponse.keys.toList()}');

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

      _logger.i('🧾 Business ID: $businessId');
      _logger.i('🧾 Trusted Partner ID: $trustedPartnerId');
      _logger.i('🧾 Member: ${memberData?['name']} ${memberData?['surname']}');
      _logger.i('🧾 Business: ${businessData?['name']}');
      _logger.i('🧾 Discount: ${discountData?['name']}');

      print('🧾 Business ID: $businessId');
      print('🧾 Trusted Partner ID: $trustedPartnerId');

      if (businessId == null) {
        _logger.e('❌ Cannot generate receipt: business_id is null');
        print('❌ ERROR: business_id is null');
        return;
      }

      // Generate sequential receipt number
      _logger.i('🧾 Step 3: Generating sequential receipt number...');
      String receiptNumber;
      try {
        final result = await _supabase.rpc(
          'get_next_receipt_number',
          params: {'p_business_id': businessId},
        );
        receiptNumber = result as String;
        _logger.i('🧾 ✅ Sequential receipt number: $receiptNumber');
        print('🧾 ✅ Sequential receipt number: $receiptNumber');
      } catch (e) {
        _logger.w('⚠️ Error generating sequential number, using fallback: $e');
        print('⚠️ Sequential numbering failed: $e');
        receiptNumber = 'RCP-${DateTime.now().millisecondsSinceEpoch}';
        _logger.i('🧾 Using fallback receipt number: $receiptNumber');
      }

      final qrCode = 'RECEIPT:${widget.dealId}:$receiptNumber';

      // Determine payment method
      String paymentMethod = 'in_app'; // Default for automated generation

      final receiptData = {
        'receipt_number': receiptNumber,
        'deal_authorization_id': widget.dealId,
        'business_name': businessData?['name'] ?? 'Unknown Business',
        'business_id': businessId,
        'member_name':
            '${memberData?['name'] ?? 'Unknown'} ${memberData?['surname'] ?? 'Member'}',
        'member_email': memberData?['email'] ?? 'N/A',
        'discount_name': discountData?['name'] ?? 'Unknown Deal',
        'amount': dealData['amount'] ?? 0.0,
        'payment_method': paymentMethod,
        'transaction_date': DateTime.now().toUtc().toIso8601String(),
        'status': 'completed',
      };

      _logger.i('🧾 Step 4: Receipt data prepared');
      _logger.i('🧾 Receipt data: $receiptData');

      // Insert into virtual_receipts table
      _logger.i('🧾 Step 5: Inserting into virtual_receipts table...');
      print('🧾 Step 5: Inserting into virtual_receipts table...');
      print('🧾 Data to insert:');
      print('🧾   deal_authorization_id: ${widget.dealId}');
      print('🧾   receipt_number: $receiptNumber');
      print('🧾   qr_code: $qrCode');
      print('🧾   receipt_data keys: ${receiptData.keys.toList()}');

      try {
        final virtualReceiptResponse = await _supabase
            .from('virtual_receipts')
            .insert({
              'deal_authorization_id': widget.dealId,
              'receipt_number': receiptNumber,
              'receipt_data': receiptData,
              'qr_code': qrCode,
            })
            .select()
            .single();

        _logger.i('✅ Virtual receipt created: ${virtualReceiptResponse['id']}');
        print('✅ Virtual receipt ID: ${virtualReceiptResponse['id']}');
      } catch (e, stackTrace) {
        _logger.e('❌ VIRTUAL_RECEIPTS INSERT FAILED: $e');
        print('❌ ========================================');
        print('❌ VIRTUAL_RECEIPTS INSERT FAILED');
        print('❌ Error: $e');
        print('❌ Stack trace: $stackTrace');
        print('❌ ========================================');
        rethrow;
      }

      // Insert into deal_receipts table for trusted partner
      _logger.i('🧾 Step 6: Inserting into deal_receipts table...');
      print('🧾 Step 6: Inserting into deal_receipts table...');
      print('🧾 Data to insert:');
      print('🧾   member_id: ${memberData?['id']}');
      print('🧾   trusted_partner_id: ${dealData['trusted_partner_id']}');
      print('🧾   deal_authorization_id: ${widget.dealId}');
      print('🧾   receipt_number: $receiptNumber');

      try {
        await _supabase.from('deal_receipts').insert({
          'member_id': memberData?['id'],
          'trusted_partner_id': trustedPartnerId,
          'business_id': businessId,
          'deal_authorization_id': widget.dealId,
          'receipt_number': receiptNumber,
          'amount': dealData['amount'],
          'business_name': businessData?['name'],
          'discount_name': discountData?['name'],
          'member_name':
              '${memberData?['name'] ?? 'Unknown'} ${memberData?['surname'] ?? 'Member'}',
          'member_email': memberData?['email'],
          'payment_method': paymentMethod,
        });

        _logger.i('✅ Deal receipt created successfully');
        print('✅ Deal receipt created successfully');
      } catch (e, stackTrace) {
        _logger.e('❌ DEAL_RECEIPTS INSERT FAILED: $e');
        print('❌ ========================================');
        print('❌ DEAL_RECEIPTS INSERT FAILED');
        print('❌ Error: $e');
        print('❌ Stack trace: $stackTrace');
        print('❌ ========================================');
        rethrow;
      }

      // Send notification to trusted partner about payment completion
      if (trustedPartnerId != null) {
        _logger.i(
          '📧 Step 7: Sending payment notification to trusted partner...',
        );
        print('📧 Sending notification to trusted partner: $trustedPartnerId');

        try {
          await _supabase.from('notifications').insert({
            'user_id': trustedPartnerId,
            'title': 'Payment Received',
            'message':
                'Member ${memberData?['name']} ${memberData?['surname']} has completed payment for ${discountData?['name']}. Receipt #$receiptNumber generated.',
            'type': 'payment_completed',
            'data': {
              'deal_authorization_id': widget.dealId,
              'receipt_number': receiptNumber,
              'amount': dealData['amount'],
              'member_name': '${memberData?['name']} ${memberData?['surname']}',
            },
            'is_read': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });

          _logger.i('✅ Notification sent to trusted partner');
          print('✅ Notification sent successfully');
        } catch (e) {
          _logger.w('⚠️ Failed to send notification: $e');
          print('⚠️ Notification failed: $e');
        }
      }

      _logger.i('🧾 ========================================');
      _logger.i('🧾 ✅ RECEIPT AUTO-GENERATION COMPLETE');
      _logger.i('🧾 Receipt Number: $receiptNumber');
      _logger.i('🧾 Deal ID: ${widget.dealId}');
      _logger.i('🧾 ========================================');

      print('🧾 ========================================');
      print('🧾 ✅ RECEIPT AUTO-GENERATED SUCCESSFULLY');
      print('🧾 Receipt Number: $receiptNumber');
      print('🧾 Deal ID: ${widget.dealId}');
      print('🧾 Member: ${memberData?['name']} ${memberData?['surname']}');
      print('🧾 Business: ${businessData?['name']}');
      print('🧾 ========================================');

      // Check subaccount verification status after payment
      if (trustedPartnerId != null) {
        _logger.i('🏦 Checking Paystack subaccount verification status...');
        print('🏦 ========================================');
        print('🏦 CHECKING SUBACCOUNT VERIFICATION STATUS');
        print('🏦 Trusted Partner ID: $trustedPartnerId');

        try {
          // Prefer newest banking table for subaccount info
          Map<String, dynamic>? bankingData;
          String? subaccountCode;
          try {
            bankingData = await _supabase
                .from('trusted_partner_bank_accounts')
                .select('subaccount_code, subaccount_active')
                .eq('user_id', trustedPartnerId)
                .eq('is_active', true)
                .maybeSingle();
            if (bankingData != null &&
                (bankingData['subaccount_active'] ?? false)) {
              subaccountCode = bankingData['subaccount_code'] as String?;
            }
          } catch (e) {
            _logger.w('⚠️ Failed to fetch banking table subaccount: $e');
          }
          // Fallback to legacy trusted_partners column if new table missing
          if (subaccountCode == null || subaccountCode.isEmpty) {
            final tpResponse = await _supabase
                .from('trusted_partners')
                .select('paystack_subaccount_code')
                .eq('id', trustedPartnerId)
                .maybeSingle();
            subaccountCode = tpResponse?['paystack_subaccount_code'] as String?;
          }

          if (subaccountCode != null && subaccountCode.isNotEmpty) {
            _logger.i('🏦 Subaccount code: $subaccountCode');
            print('🏦 Subaccount code: $subaccountCode');

            // Fetch subaccount details from Paystack
            final paystack = PaystackService();
            final subaccountDetails = await paystack.getSubaccount(
              subaccountCode,
            );

            if (subaccountDetails != null) {
              final accountName = subaccountDetails['account_name'];
              final settlementBank = subaccountDetails['settlement_bank'];

              _logger.i('🏦 Subaccount Status:');
              _logger.i('   Account Name: $accountName');
              _logger.i('   Settlement Bank: $settlementBank');
              _logger.i('   Full details: $subaccountDetails');

              print('🏦 Subaccount Status:');
              print('   Account Name: $accountName');
              print('   Settlement Bank: $settlementBank');
              print('🏦 ========================================');

              // Note: Paystack doesn't return a direct "verified" field
              // Bank accounts are verified during subaccount creation via /bank/resolve
              // If subaccount exists with settlement_bank set, it should be verified
              // Unverified status usually means verification failed during creation
              if (settlementBank == null || accountName == null) {
                _logger.w('⚠️ WARNING: Subaccount may be unverified!');
                _logger.w(
                  '   This can happen if bank account verification failed.',
                );
                _logger.w('   Business should update their banking details.');
                print(
                  '⚠️ WARNING: Subaccount appears unverified - missing bank details',
                );
              } else {
                _logger.i('✅ Subaccount appears verified with bank details');
                print('✅ Subaccount has valid bank details');
              }
            } else {
              _logger.w('⚠️ Could not fetch subaccount details from Paystack');
              print('⚠️ Could not fetch subaccount details');
            }
          } else {
            _logger.w(
              '⚠️ No Paystack subaccount code found for trusted partner',
            );
            print('⚠️ No subaccount code found');
          }
          print('🏦 ========================================');
        } catch (e) {
          _logger.w('⚠️ Error checking subaccount status: $e');
          print('⚠️ Subaccount status check failed: $e');
          print('🏦 ========================================');
          // Don't throw - this is just for logging/diagnostics
        }
      }
    } catch (e, stackTrace) {
      _receiptGenerated = false; // Reset flag on failure to allow retry
      _logger.e('❌ Error auto-generating receipt: $e');
      _logger.e('❌ Stack trace: $stackTrace');
      print('❌ ========================================');
      print('❌ RECEIPT AUTO-GENERATION FAILED');
      print('❌ Deal ID: ${widget.dealId}');
      print('❌ Error: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ ========================================');
      // Don't throw - payment was successful, receipt generation failure shouldn't block user
    }
  }

  void _startSuccessPolling() {
    _successCheckTimer?.cancel();
    int pollCount = 0;
    const maxPolls = 15; // Poll for 15 seconds to give Paystack time to load
    bool successUrlDetected = false;

    _successCheckTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      pollCount++;
      _logger.d('Polling for success... attempt $pollCount/$maxPolls');

      try {
        // Check for MutationObserver signal first
        final hasObserverSignal = await _controller
            .runJavaScriptReturningResult(
              "document.body.getAttribute('data-payment-success') === 'true'",
            );

        if (hasObserverSignal == true ||
            hasObserverSignal.toString() == 'true') {
          _logger.i('✅ MutationObserver detected success!');
          timer.cancel();
          _handlePaymentSuccess();
          return;
        }

        // Enhanced: Check page HTML content for success indicators
        final contentCheckScript = '''
          (function() {
            const html = document.documentElement.innerHTML.toLowerCase();
            const bodyText = document.body.innerText.toLowerCase();
            
            // Check multiple success patterns
            const successPatterns = [
              "payment successful",
              "you paid",
              "transaction successful", 
              "payment complete",
              "payment was successful",
              "transaction complete",
              "successfully paid",
              "payment confirmed"
            ];
            
            for (const pattern of successPatterns) {
              if (bodyText.includes(pattern) || html.includes(pattern)) {
                console.log('✅ Found success pattern: ' + pattern);
                return true;
              }
            }
            
            // Check for success icons/images
            if (html.includes('success') && (html.includes('icon') || html.includes('check'))) {
              console.log('✅ Found success icon indicator');
              return true;
            }
            
            return false;
          })()
        ''';

        final hasSuccess = await _controller.runJavaScriptReturningResult(
          contentCheckScript,
        );

        if (hasSuccess == true || hasSuccess.toString() == 'true') {
          _logger.i('✅ Polling detected success in page content!');
          successUrlDetected = true;
          timer.cancel();
          _handlePaymentSuccess();
          return;
        }

        // Check current URL for success indicators
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null && _isPaystackSuccessUrl(currentUrl)) {
          _logger.i('✅ Polling detected success in URL: $currentUrl');
          successUrlDetected = true;
          timer.cancel();
          _handlePaymentSuccess(url: currentUrl);
          return;
        }
      } catch (e) {
        _logger.w('Polling error: $e');
      }

      if (pollCount >= maxPolls) {
        _logger.w('Polling timed out after $maxPolls seconds');
        timer.cancel();

        // Hard timeout fallback: if we detected a success URL earlier but couldn't
        // confirm via content, trigger success anyway after timeout
        if (successUrlDetected) {
          _logger.i(
            '⏱️ Hard timeout: Triggering success based on earlier URL detection',
          );
          _handlePaymentSuccess();
        } else {
          _logger.w(
            '⏱️ Hard timeout: No success detected - consider manual return',
          );
        }
      }
    });
  }

  Future<void> _handleManualReturn() async {
    print('🔵 ========================================');
    print('🔵 MANUAL RETURN BUTTON CLICKED');
    print('🔵 Deal ID: ${widget.dealId}');
    print('🔵 ========================================');

    _logger.i('Manual return from payment for deal: ${widget.dealId}');

    // If payment not yet verified by success handler, attempt on-demand verification using current URL
    if (!_paymentVerified) {
      try {
        final currentUrl = await _controller.currentUrl();
        _logger.d('Manual return current URL: $currentUrl');

        String? ref;

        // Try to extract reference from URL
        if (currentUrl != null) {
          ref = _extractReferenceFromUrl(currentUrl);
        }

        // If not in URL, try extracting from page JavaScript/content
        if (ref == null) {
          _logger.i('Reference not in URL, trying page extraction...');
          ref = await _extractReferenceFromPage();
        }

        if (ref == null) {
          _logger.w(
            'Manual return: No reference found yet; payment likely still in progress.',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment still processing. Please wait for completion before returning.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return; // Do not proceed to generate receipt prematurely
        }

        _logger.i(
          'Manual return: Verifying transaction before recording. Ref=$ref',
        );

        // Retry verification with exponential backoff (transaction might not be indexed yet)
        Map<String, dynamic>? details;
        int retryCount = 0;
        const maxRetries = 3;

        while (retryCount < maxRetries) {
          try {
            details = await PaystackService().verifyTransaction(ref);
            if (details != null) {
              _logger.i(
                '✅ Verification succeeded on attempt ${retryCount + 1}',
              );
              break;
            }
          } catch (e) {
            _logger.w('Verification attempt ${retryCount + 1} failed: $e');
          }

          retryCount++;
          if (retryCount < maxRetries) {
            final delaySeconds = retryCount * 2; // 2s, 4s backoff
            _logger.i('Retrying verification in ${delaySeconds}s...');
            await Future.delayed(Duration(seconds: delaySeconds));
          }
        }

        if (details == null) {
          _logger.w(
            'Manual return: Verification failed after $maxRetries attempts.',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Payment verification incomplete. Please try again in a moment, or contact support if this persists.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // Mark verified
        _paymentVerified = true;
        _logger.i(
          'Manual return: Transaction verified. Proceeding to record payment.',
        );
      } catch (e) {
        _logger.w('Manual return verification error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not verify payment yet: $e'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    setState(() => _generatingReceipt = true);

    // Update payment_completed_at timestamp (status stays 'approved')
    // Trusted partner will issue receipt later
    try {
      // Check authentication context
      final currentUser = _supabase.auth.currentUser;
      _logger.i('🔐 Manual Return - Current user: ${currentUser?.id}');

      final now = DateTime.now().toUtc().toIso8601String();
      _logger.i(
        '💰 Manual Return: Updating payment_completed_at and completed_at for deal: ${widget.dealId} to $now (UTC)',
      );

      print('🔐 ========================================');
      print('🔐 MANUAL RETURN - AUTHENTICATION CHECK');
      print('🔐 User ID: ${currentUser?.id}');
      print('🔐 User Email: ${currentUser?.email}');
      print('🔐 Deal ID: ${widget.dealId}');
      print('🔐 ========================================');

      final response = await _supabase
          .from('deal_authorizations')
          .update({
            'payment_completed_at': now,
            'completed_at': now, // Also update completed_at
            'updated_at': now,
          })
          .eq('id', widget.dealId)
          .select();

      _logger.i('✅ Payment timestamp updated via manual return');
      _logger.i('✅ Update response: $response');

      print('💰 ========================================');
      print('💰 MANUAL RETURN - PAYMENT TIMESTAMP UPDATE');
      print('💰 Deal ID: ${widget.dealId}');
      print('💰 payment_completed_at: $now');
      print('💰 Response: $response');
      print('💰 ========================================');

      // Auto-generate receipt after manual return
      await _autoGenerateReceipt();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed! Receipt generated.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      _logger.e('❌ Error updating payment timestamp: $e');
      print('❌ ========================================');
      print('❌ MANUAL RETURN - UPDATE FAILED');
      print('❌ Deal ID: ${widget.dealId}');
      print('❌ Error: $e');
      print('❌ ========================================');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording payment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _generatingReceipt = false);

    // Navigate to Members Home Page
    if (mounted) {
      _logger.i('Navigating to Members Home after manual return');
      await NavigationService().navigateToHomeAfterPayment(context);
    }
  }

  @override
  void dispose() {
    _successCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() => _loading = true);
            _logger.d('Page started loading: $url');
          },
          onPageFinished: (url) async {
            setState(() => _loading = false);
            _logger.i('=== PAGE FINISHED LOADING ===');
            _logger.i('URL: $url');

            // Check if this is a success page by URL
            if (_isPaystackSuccessUrl(url)) {
              _logger.i('✅ Detected Paystack success URL: $url');
              _handlePaymentSuccess(url: url);
              return;
            }

            // Check if the page title contains 'Payment Successful'
            try {
              final pageTitle = await _controller.getTitle();
              _logger.d('Page title: $pageTitle');
              if (pageTitle != null &&
                  (pageTitle.toLowerCase().contains('payment successful') ||
                      pageTitle.toLowerCase().contains(
                        'transaction successful',
                      ))) {
                _logger.i(
                  '✅ Detected Paystack success by page title: $pageTitle',
                );
                _handlePaymentSuccess();
                return;
              }
            } catch (e) {
              _logger.w('Could not get WebView page title: $e');
            }

            // If on Paystack page, inject MutationObserver and start polling
            if (url.contains('paystack.com')) {
              _logger.i(
                'On Paystack page - injecting MutationObserver and starting polling',
              );

              // Inject MutationObserver to watch for dynamic content changes
              try {
                await _controller.runJavaScript('''
                  (function() {
                    // Check if observer already exists
                    if (window.paystackSuccessObserver) {
                      console.log('MutationObserver already initialized');
                      return;
                    }
                    
                    const successKeywords = [
                      'payment successful',
                      'transaction successful', 
                      'you paid',
                      'payment complete',
                      'payment was successful',
                      'transaction complete',
                      'successfully paid',
                      'payment confirmed'
                    ];
                    
                    function checkForSuccess() {
                      const bodyText = document.body.innerText.toLowerCase();
                      const htmlContent = document.documentElement.innerHTML.toLowerCase();
                      
                      // Check for success text in body
                      const hasSuccessText = successKeywords.some(keyword => 
                        bodyText.includes(keyword) || htmlContent.includes(keyword)
                      );
                      
                      // Check for success icons/images
                      const hasSuccessIcon = htmlContent.includes('success') && 
                                            (htmlContent.includes('icon') || htmlContent.includes('check'));
                      
                      if (hasSuccessText || hasSuccessIcon) {
                        console.log('✅ MutationObserver detected success in page content');
                        // Signal to Flutter - mark in DOM for polling to detect
                        document.body.setAttribute('data-payment-success', 'true');
                        console.log('✅ Set data-payment-success attribute');
                      }
                    }
                    
                    // Initial check immediately
                    checkForSuccess();
                    
                    // Check again after a short delay (for dynamically loaded content)
                    setTimeout(checkForSuccess, 500);
                    setTimeout(checkForSuccess, 1000);
                    setTimeout(checkForSuccess, 2000);
                    
                    // Set up MutationObserver to watch for DOM changes
                    const observer = new MutationObserver(function(mutations) {
                      checkForSuccess();
                    });
                    
                    observer.observe(document.body, {
                      childList: true,
                      subtree: true,
                      characterData: true,
                      attributes: true
                    });
                    
                    window.paystackSuccessObserver = observer;
                    console.log('MutationObserver initialized for success detection');
                  })();
                ''');
                _logger.i('MutationObserver injected successfully');
              } catch (e) {
                _logger.w('Failed to inject MutationObserver: $e');
              }

              _startSuccessPolling();
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            _logger.d('Navigation request: $url');

            // Detect callback URL
            if (url.startsWith(_callbackUrl)) {
              _logger.i('Detected callback URL: $url');
              _handlePaymentSuccess(url: url);
              return NavigationDecision.prevent;
            }

            // Detect success pages
            if (_isPaystackSuccessUrl(url)) {
              _logger.i('Detected success URL in navigation: $url');
              _handlePaymentSuccess(url: url);
            }

            // Detect cancellation paths from Paystack
            final lower = url.toLowerCase();
            if (lower.contains('cancel') || lower.contains('close')) {
              _logger.w('Detected cancellation URL: $url');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment cancelled'),
                    duration: Duration(seconds: 2),
                  ),
                );
                // Go back to Members Home
                NavigationService().navigateToHomeAfterPayment(context);
                return NavigationDecision.prevent;
              }
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back navigation if payment was successful or processing
        if (_showingSuccess || _processingPayment) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please use the "Return Home" button'),
              duration: Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Secure Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: (_processingPayment || _showingSuccess)
                ? null
                : () async {
                    // Offer to record success before leaving
                    final choice = await showModalBottomSheet<String>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              title: const Text(
                                'Payment successful – Return home',
                              ),
                              subtitle: const Text(
                                'Record payment and generate receipt',
                              ),
                              onTap: () => Navigator.pop(ctx, 'success'),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.close),
                              title: const Text('Cancel/Close'),
                              onTap: () => Navigator.pop(ctx, 'cancel'),
                            ),
                          ],
                        ),
                      ),
                    );

                    if (choice == 'success') {
                      await _handleManualReturn();
                    } else if (choice == 'cancel') {
                      if (mounted) Navigator.of(context).pop();
                    }
                  },
          ),
        ),
        body: Stack(
          children: [
            // Only show WebView when not showing success
            if (!_showingSuccess) WebViewWidget(controller: _controller),
            if (_loading && !_processingPayment && !_showingSuccess)
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            if (_processingPayment || _showingSuccess)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_showingSuccess) ...[
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 24),
                        const Text(
                          'Processing payment...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Payment Successful!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your payment has been processed successfully',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Receipt generated automatically',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 48),
                        ElevatedButton.icon(
                          onPressed: _generatingReceipt
                              ? null
                              : () async {
                                  await _handleManualReturn();
                                },
                          icon: _generatingReceipt
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.home),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 4,
                          ),
                          label: Text(
                            _generatingReceipt
                                ? 'Processing...'
                                : 'Return to Home',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            // Always-available fallback action so users can proceed
            if (!_processingPayment && !_showingSuccess)
              Positioned(
                left: 16,
                right: 16,
                bottom: 24,
                child: ElevatedButton.icon(
                  onPressed: _generatingReceipt
                      ? null
                      : () async {
                          await _handleManualReturn();
                        },
                  icon: _generatingReceipt
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _generatingReceipt
                        ? 'Recording payment...'
                        : 'Payment successful? Return home',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
