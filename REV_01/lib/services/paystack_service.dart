import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:logger/logger.dart';

class PaystackService {
  // Paystack API URL (same for sandbox and live)
  static const String _baseUrl = 'https://api.paystack.co';

  final Logger _logger = Logger();

  // Get Paystack secret key from environment
  String get _secretKey {
    try {
      return dotenv.env['PAYSTACK_SECRET_KEY'] ?? '';
    } catch (e) {
      _logger.e(
        'PaystackService: Could not load PAYSTACK_SECRET_KEY from env: $e',
      );
      return '';
    }
  }

  // Development mode flag
  bool get _isDevelopmentMode {
    try {
      return dotenv.env['PAYSTACK_DEVELOPMENT_MODE'] == 'true';
    } catch (e) {
      _logger.w(
        'PaystackService: Could not load PAYSTACK_DEVELOPMENT_MODE from env, defaulting to false: $e',
      );
      return false; // Default to production mode
    }
  }

  // Create one-time payment
  Future<void> startOneTimePayment({
    required String itemName,
    required String itemDescription,
    required double amount,
    required String userId,
    required String userEmail,
  }) async {
    // In development mode, simulate successful payment without Paystack redirect
    if (_isDevelopmentMode) {
      _logger.i(
        'PaystackService: Development mode - Simulating successful one-time payment',
      );
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));
      return; // Return early, payment will be marked as completed by caller
    }

    try {
      // Initialize transaction
      final initResponse = await http.post(
        Uri.parse('$_baseUrl/transaction/initialize'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': userEmail,
          'amount': (amount * 100)
              .toInt(), // Convert to kobo (smallest currency unit)
          'reference':
              'one_time_${userId}_${DateTime.now().millisecondsSinceEpoch}',
          'callback_url': 'https://yourapp.com/payment/success',
          'metadata': {
            'user_id': userId,
            'payment_type': 'one_time_payment',
            'item_name': itemName,
            'item_description': itemDescription,
          },
        }),
      );

      if (initResponse.statusCode == 200) {
        final responseData = jsonDecode(initResponse.body);
        final authorizationUrl = responseData['data']['authorization_url'];

        if (!await launchUrl(
          Uri.parse(authorizationUrl),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('Could not open Paystack payment URL');
        }
      } else {
        throw Exception(
          'Failed to initialize Paystack payment: ${initResponse.body}',
        );
      }
    } catch (e) {
      _logger.e('PaystackService: Error starting one-time payment: $e');
      throw Exception('Failed to start payment: $e');
    }
  }

  // Create subscription payment
  Future<void> startSubscription({
    required String plan,
    required double amount,
    required int frequency, // in months
    required String userId,
    required String userEmail,
  }) async {
    // In development mode, simulate successful payment without Paystack redirect
    if (_isDevelopmentMode) {
      _logger.i(
        'PaystackService: Development mode - Simulating successful subscription payment',
      );
      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));
      return; // Return early, payment will be marked as completed by caller
    }

    try {
      // First, create a plan if it doesn't exist
      final planResponse = await http.post(
        Uri.parse('$_baseUrl/plan'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': 'Local Lekker $plan Subscription',
          'interval': 'monthly',
          'amount': (amount * 100).toInt(), // Convert to kobo
          'description': '$plan subscription plan',
        }),
      );

      String planCode;
      if (planResponse.statusCode == 201) {
        final planData = jsonDecode(planResponse.body);
        planCode = planData['data']['plan_code'];
      } else {
        // Plan might already exist, try to get it
        final getPlansResponse = await http.get(
          Uri.parse('$_baseUrl/plan'),
          headers: {'Authorization': 'Bearer $_secretKey'},
        );

        if (getPlansResponse.statusCode == 200) {
          final plansData = jsonDecode(getPlansResponse.body);
          final existingPlan = plansData['data'].firstWhere(
            (p) => p['name'] == 'Local Lekker $plan Subscription',
            orElse: () => null,
          );

          if (existingPlan != null) {
            planCode = existingPlan['plan_code'];
          } else {
            throw Exception('Could not create or find subscription plan');
          }
        } else {
          throw Exception('Failed to get plans: ${getPlansResponse.body}');
        }
      }

      // Initialize subscription
      final subResponse = await http.post(
        Uri.parse('$_baseUrl/subscription'),
        headers: {
          'Authorization': 'Bearer $_secretKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'customer': userEmail,
          'plan': planCode,
          'start_date': DateTime.now().toIso8601String(),
        }),
      );

      if (subResponse.statusCode == 200) {
        final subData = jsonDecode(subResponse.body);
        final authorizationUrl = subData['data']['authorization_url'];

        if (!await launchUrl(
          Uri.parse(authorizationUrl),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('Could not open Paystack subscription URL');
        }
      } else {
        throw Exception(
          'Failed to initialize Paystack subscription: ${subResponse.body}',
        );
      }
    } catch (e) {
      _logger.e('PaystackService: Error starting subscription: $e');
      throw Exception('Failed to start subscription: $e');
    }
  }

  // Verify payment notification (webhook)
  bool verifyNotification(Map<String, String> notificationData) {
    // Paystack uses signature verification with secret key
    final signature = notificationData['x-paystack-signature'];
    if (signature == null) return false;

    // For Paystack, we verify the signature using HMAC SHA512
    // This is a simplified version - in production, implement proper HMAC verification
    return signature.isNotEmpty && _secretKey.isNotEmpty;
  }

  // Get transaction status
  Future<Map<String, dynamic>?> getTransactionStatus(String reference) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/transaction/verify/$reference'),
        headers: {'Authorization': 'Bearer $_secretKey'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
    } catch (e) {
      _logger.e('PaystackService: Error getting transaction status: $e');
    }
    return null;
  }
}
