import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

class PaystackWebhookHandler {
  static final PaystackWebhookHandler _instance =
      PaystackWebhookHandler._internal();
  factory PaystackWebhookHandler() => _instance;
  PaystackWebhookHandler._internal();

  final _supabase = Supabase.instance.client;
  final Logger _logger = Logger();

  /// Process Paystack webhook
  /// This should be called from your server endpoint that receives Paystack webhooks
  Future<bool> processWebhook(Map<String, dynamic> webhookData) async {
    try {
      _logger.i(
        'PaystackWebhookHandler: Processing webhook: ${webhookData['event']}',
      );

      final event = webhookData['event'];
      final data = webhookData['data'];

      if (data == null) {
        _logger.w('PaystackWebhookHandler: No data in webhook');
        return false;
      }

      switch (event) {
        case 'charge.success':
          return await _handleChargeSuccess(data);
        case 'subscription.create':
          return await _handleSubscriptionCreate(data);
        case 'invoice.payment_failed':
          return await _handlePaymentFailed(data);
        case 'subscription.disable':
          return await _handleSubscriptionDisable(data);
        default:
          _logger.w('PaystackWebhookHandler: Unhandled event: $event');
          return true; // Acknowledge unhandled events
      }
    } catch (e) {
      _logger.e('PaystackWebhookHandler: Error processing webhook: $e');
      return false;
    }
  }

  Future<bool> _handleChargeSuccess(Map<String, dynamic> data) async {
    try {
      final reference = data['reference'];
      final amount = data['amount']; // Amount in kobo
      final customer = data['customer'];
      final metadata = data['metadata'] ?? {};

      _logger.i(
        'PaystackWebhookHandler: Processing successful charge: $reference',
      );

      // Extract user information from metadata or customer data
      final userId = metadata['user_id'] ?? customer['email'];
      final paymentType = metadata['payment_type'] ?? 'unknown';

      if (userId == null) {
        _logger.w('PaystackWebhookHandler: Missing user ID in charge success');
        return false;
      }

      // Record the payment in database
      final paymentRecord = {
        'user_id': userId,
        'amount': amount / 100, // Convert from kobo to currency units
        'currency': 'NGN',
        'reference': reference,
        'status': 'completed',
        'payment_method': 'Paystack',
        'payment_type': paymentType,
        'metadata': jsonEncode(metadata),
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('payments').insert(paymentRecord);

      if (paymentType == 'subscription') {
        // Update user membership if this is a subscription payment
        final planName = metadata['plan_name'] ?? 'premium';
        await _updateUserMembership(userId, planName);
      }

      _logger.i(
        'PaystackWebhookHandler: Charge success processed for user: $userId',
      );
      return true;
    } catch (e) {
      _logger.e('PaystackWebhookHandler: Error handling charge success: $e');
      return false;
    }
  }

  Future<bool> _handleSubscriptionCreate(Map<String, dynamic> data) async {
    try {
      final subscriptionCode = data['subscription_code'];
      final customer = data['customer'];
      final plan = data['plan'];

      _logger.i(
        'PaystackWebhookHandler: Processing subscription create: $subscriptionCode',
      );

      final userId = customer['email']; // Assuming email is used as user ID
      final planName =
          plan['name']
              ?.replaceFirst('Local Lekker ', '')
              ?.replaceFirst(' Subscription', '') ??
          'premium';

      // Update user membership
      await _updateUserMembership(userId, planName);

      // Record subscription
      final subscriptionRecord = {
        'user_id': userId,
        'subscription_code': subscriptionCode,
        'plan_name': planName,
        'status': 'active',
        'amount': plan['amount'] / 100, // Convert from kobo
        'currency': 'NGN',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('subscriptions').insert(subscriptionRecord);

      _logger.i(
        'PaystackWebhookHandler: Subscription created for user: $userId',
      );
      return true;
    } catch (e) {
      _logger.e(
        'PaystackWebhookHandler: Error handling subscription create: $e',
      );
      return false;
    }
  }

  Future<bool> _handlePaymentFailed(Map<String, dynamic> data) async {
    try {
      final subscriptionCode = data['subscription_code'];
      _logger.w(
        'PaystackWebhookHandler: Processing payment failed for subscription: $subscriptionCode',
      );

      // Update subscription status
      await _supabase
          .from('subscriptions')
          .update({'status': 'payment_failed'})
          .eq('subscription_code', subscriptionCode);

      // Could also notify user about failed payment
      _logger.i(
        'PaystackWebhookHandler: Payment failed processed for subscription: $subscriptionCode',
      );
      return true;
    } catch (e) {
      _logger.e('PaystackWebhookHandler: Error handling payment failed: $e');
      return false;
    }
  }

  Future<bool> _handleSubscriptionDisable(Map<String, dynamic> data) async {
    try {
      final subscriptionCode = data['subscription_code'];
      final customer = data['customer'];

      _logger.i(
        'PaystackWebhookHandler: Processing subscription disable: $subscriptionCode',
      );

      final userId = customer['email'];

      // Update subscription status
      await _supabase
          .from('subscriptions')
          .update({'status': 'cancelled'})
          .eq('subscription_code', subscriptionCode);

      // Downgrade user membership
      await _updateUserMembership(userId, 'free');

      _logger.i(
        'PaystackWebhookHandler: Subscription disabled for user: $userId',
      );
      return true;
    } catch (e) {
      _logger.e(
        'PaystackWebhookHandler: Error handling subscription disable: $e',
      );
      return false;
    }
  }

  Future<void> _updateUserMembership(String userId, String planName) async {
    try {
      // Map plan names to roles
      final roleMapping = {
        'free': 'free',
        'basic': 'basic',
        'premium': 'premium',
        'business': 'business',
      };

      final role = roleMapping[planName.toLowerCase()] ?? 'free';

      // Update user profile
      await _supabase
          .from('profiles')
          .update({'membership_role': role})
          .eq('id', userId);

      _logger.i('PaystackWebhookHandler: Updated user $userId role to $role');
    } catch (e) {
      _logger.e('PaystackWebhookHandler: Error updating user membership: $e');
    }
  }
}
