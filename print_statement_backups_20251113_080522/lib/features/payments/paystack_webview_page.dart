import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:local_lekker/services/navigation_service.dart';
import 'package:local_lekker/services/subscription_service.dart';
import 'package:local_lekker/services/paystack_service.dart';
import 'package:logger/logger.dart';

class PaystackWebViewPage extends StatefulWidget {
  final String authorizationUrl;
  final String userId;
  final String planType;

  const PaystackWebViewPage({
    super.key,
    required this.authorizationUrl,
    required this.userId,
    required this.planType,
  });

  @override
  State<PaystackWebViewPage> createState() => _PaystackWebViewPageState();
}

class _PaystackWebViewPageState extends State<PaystackWebViewPage> {
  final Logger _logger = Logger();
  final PaystackService _paystackService = PaystackService();
  late final WebViewController _controller;
  bool _loading = true;
  bool _processingPayment = false;
  bool _showingSuccess = false;

  String get _callbackUrl {
    // Prefer explicit callback URL if provided, else use app scheme
    final webCallbackUrl = dotenv.env['PAYSTACK_CALLBACK_URL'];
    return webCallbackUrl ?? 'locallekker://payment/callback';
  }

  bool _isPaystackSuccessUrl(String url) {
    // Check for various Paystack success indicators
    final isPaystackUrl =
        url.contains('checkout.paystack.com') || url.contains('paystack.com');
    final hasSuccessIndicator =
        url.contains('success') ||
        url.contains('trxref=') ||
        url.contains('reference=') ||
        url.contains('/receipt') ||
        url.contains('status=success');

    _logger.d(
      'Checking URL - isPaystackUrl: $isPaystackUrl, hasSuccessIndicator: $hasSuccessIndicator',
    );
    return isPaystackUrl && hasSuccessIndicator;
  }

  String? _extractReferenceFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      String? reference =
          uri.queryParameters['reference'] ?? uri.queryParameters['trxref'];
      if (reference == null || reference.isEmpty) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          reference = segments.last;
        }
      }
      return (reference != null && reference.isNotEmpty) ? reference : null;
    } catch (e) {
      _logger.w('Failed to parse reference from URL: $e');
      return null;
    }
  }

  Future<void> _handlePaymentSuccess({String? url}) async {
    print('✅ ========================================');
    print('✅ PAYMENT SUCCESS HANDLER CALLED');
    print('✅ UserId: ${widget.userId}');
    print('✅ PlanType: ${widget.planType}');
    print('✅ ========================================');
    _logger.i('=== PAYMENT SUCCESS HANDLER CALLED ===');
    // Always show Activate overlay after payment success
    setState(() {
      _processingPayment = true;
      _showingSuccess = true;
    });
    _logger.i('Activate overlay forced visible after payment success.');
    _logger.i(
      'Processing payment for userId: ${widget.userId}, planType: ${widget.planType}',
    );

    try {
      // Try to verify Paystack transaction and save authorization for renewals
      if (url != null) {
        final reference = _extractReferenceFromUrl(url);
        _logger.i('Extracted reference from URL: ${reference ?? 'none'}');
        if (reference != null) {
          try {
            _logger.i('Verifying Paystack transaction: $reference');
            final paymentDetails = await _paystackService.verifyTransaction(
              reference,
            );
            if (paymentDetails != null &&
                paymentDetails['authorization'] != null) {
              final auth = paymentDetails['authorization'];
              final authorizationCode = auth['authorization_code'];
              if (authorizationCode != null &&
                  authorizationCode.toString().isNotEmpty) {
                final existing = await _paystackService.getSavedPaymentMethods(
                  widget.userId,
                );
                final shouldSetPrimary =
                    existing.isEmpty ||
                    !existing.any((m) => m['is_primary'] == true);

                final cardDetails = {
                  'card_type': auth['card_type'] ?? 'card',
                  'last4': auth['last4'] ?? '****',
                  'exp_month': auth['exp_month'],
                  'exp_year': auth['exp_year'],
                  'bank': auth['bank'],
                  'brand': auth['brand'],
                  'is_primary': shouldSetPrimary,
                };

                _logger.i(
                  'Saving authorization_code for user ${widget.userId}: $authorizationCode',
                );
                try {
                  await _paystackService.addPaymentMethod(
                    widget.userId,
                    authorizationCode,
                    cardDetails,
                  );
                  if (shouldSetPrimary) {
                    await _paystackService.setPrimaryPaymentMethod(
                      widget.userId,
                      authorizationCode,
                    );
                  }
                } catch (e) {
                  _logger.w(
                    'addPaymentMethod failed (possibly duplicate). Continuing. Error: $e',
                  );
                }
              } else {
                _logger.w('No authorization_code found in Paystack response');
              }

              // Save customer_code to profile so subsequent checkouts
              // surface saved card with CVV-only prompt
              final customer = paymentDetails['customer'];
              final customerCode = customer != null
                  ? (customer['customer_code'] as String?)
                  : null;
              if (customerCode != null && customerCode.isNotEmpty) {
                try {
                  await _paystackService.savePaystackCustomerCode(
                    userId: widget.userId,
                    customerCode: customerCode,
                  );
                } catch (e) {
                  _logger.w('Failed saving customer_code: $e');
                }
              }
            } else {
              _logger.w('Payment verification returned no authorization data');
            }
          } catch (e) {
            _logger.w('Failed to verify transaction or save card: $e');
          }
        }
      }

      // Mark subscription active and start new billing period
      _logger.i('Calling SubscriptionService.processManualPayment...');
      final success = await SubscriptionService().processManualPayment(
        userId: widget.userId,
        planType: widget.planType,
      );

      _logger.i('processManualPayment returned: $success');

      if (!success) {
        throw Exception('processManualPayment returned false');
      }

      _logger.i('Subscription activated successfully');

      // Show success message with Activate button
      if (mounted) {
        _logger.i('Showing success message and scheduling auto-navigation...');
        setState(() {
          _showingSuccess = true;
          _processingPayment = true; // Ensure overlay stays visible
        });
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted) {
            _logger.i('Auto-navigating to Members Home after payment success.');
            setState(() {
              _processingPayment = false;
            });
            await NavigationService().navigateToHomeAfterPayment(context);
          }
        });
      } else {
        _logger.e('Widget is not mounted after processManualPayment');
      }
    } catch (e, stackTrace) {
      _logger.e('Error processing payment: $e');
      _logger.e('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _processingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful but activation failed: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
            print('🌐 WebView Page Started: $url');
          },
          onPageFinished: (url) async {
            setState(() => _loading = false);
            print('🌐 ========================================');
            print('🌐 PAGE FINISHED LOADING');
            print('🌐 URL: $url');
            _logger.i('=== PAGE FINISHED LOADING ===');
            _logger.i('URL: $url');

            // Check if this is a success page by URL
            if (_isPaystackSuccessUrl(url)) {
              _logger.i('Detected Paystack success URL: $url');
              _handlePaymentSuccess(url: url);
              return;
            }

            // Check if the page title contains 'Payment Successful' (for Paystack test mode)
            try {
              final pageTitle = await _controller.getTitle();
              _logger.i('WebView page title: $pageTitle');
              if (pageTitle != null &&
                  pageTitle.toLowerCase().contains('payment successful')) {
                _logger.i(
                  'Detected Paystack success by page title: $pageTitle',
                );
                _handlePaymentSuccess(url: url);
                return;
              }
            } catch (e) {
              _logger.w('Could not get WebView page title: $e');
            }

            // Additional check: look for success indicators in the page content via JavaScript
            if (url.contains('paystack.com')) {
              try {
                _logger.d('Checking page content for success indicators...');
                // More aggressive content detection
                final successScript = '''
                  (function() {
                    const bodyText = document.body.innerText.toLowerCase();
                    const hasPaymentSuccessful = bodyText.includes("payment successful");
                    const hasYouPaid = bodyText.includes("you paid");
                    const hasTransactionSuccessful = bodyText.includes("transaction successful");
                    const hasSuccessClass = document.querySelector(".success") !== null;
                    const hasCheckmark = document.querySelector('[class*="check"]') !== null || 
                                         document.querySelector('[class*="success"]') !== null;
                    
                    console.log('Payment detection:', {
                      hasPaymentSuccessful,
                      hasYouPaid,
                      hasTransactionSuccessful,
                      hasSuccessClass,
                      hasCheckmark
                    });
                    
                    return hasPaymentSuccessful || hasYouPaid || hasTransactionSuccessful || 
                           hasSuccessClass || hasCheckmark;
                  })()
                ''';

                final hasSuccessButton = await _controller
                    .runJavaScriptReturningResult(successScript);
                _logger.i(
                  'Enhanced page content check result: $hasSuccessButton',
                );
                print('🔍 Enhanced detection result: $hasSuccessButton');

                if (hasSuccessButton == true ||
                    hasSuccessButton.toString() == 'true') {
                  _logger.i(
                    '✅ Detected success by enhanced page content analysis',
                  );
                  print('✅ AUTO-DETECTING PAYMENT SUCCESS FROM PAGE CONTENT');
                  _handlePaymentSuccess();
                  return;
                }
              } catch (e) {
                _logger.w('Could not check page content: $e');
              }
            }

            _logger.d('No success indicators detected on this page');
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            _logger.d('Navigation request: $url');

            // Detect Paystack returning to our callback URL
            if (url.startsWith(_callbackUrl)) {
              _logger.i('Detected callback URL: $url');
              _handlePaymentSuccess(url: url);
              return NavigationDecision.prevent;
            }

            // Detect Paystack success pages
            if (_isPaystackSuccessUrl(url)) {
              _logger.i('Detected success URL in navigation: $url');
              _handlePaymentSuccess(url: url);
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _processingPayment
              ? null
              : () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading && !_processingPayment)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          if (_processingPayment)
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
                        decoration: BoxDecoration(
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
                        'Payment Successful! Redirecting...',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'You will be redirected to your home page.',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          // Manual activation button - always visible unless showing success overlay
          if (!_showingSuccess)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: _processingPayment
                      ? null
                      : () {
                          print('🔘 MANUAL ACTIVATE BUTTON PRESSED');
                          _handlePaymentSuccess();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'Activate Subscription',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
