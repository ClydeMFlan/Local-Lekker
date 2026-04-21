import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'qr_code_service.dart';
import 'package:logger/logger.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final Logger _logger = Logger();
  Timer? _countdownTimer;

  /// Create initial subscription and QR code for new user
  Future<void> createInitialSubscription({
    required String userId,
    required String planType,
    required bool autoRenew,
  }) async {
    try {
      // Fetch user's name and surname
      final profile = await _client
          .from('profiles')
          .select('name, surname')
          .eq('id', userId)
          .single();

      final name = profile['name'] as String? ?? 'Unknown';
      final surname = profile['surname'] as String? ?? 'Unknown';

      // Generate initial QR code
      final qrCode = await QrCodeService().generateUniqueQrCode(userId);

      // Create QR code record
      await _client.from('user_qr_codes').insert({
        'user_id': userId,
        'qr_code': qrCode,
        'name': name,
        'surname': surname,
        'is_active': true,
        'expires_at': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      });

      // Create subscription record
      await _client.from('subscriptions').insert({
        'user_id': userId,
        'plan_type': planType,
        'auto_renew': autoRenew,
        'status': 'active',
        'current_period_start': DateTime.now().toIso8601String(),
        'current_period_end': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'next_payment_date': autoRenew
            ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
            : null,
      });
    } catch (e) {
      _logger.e('Error creating initial subscription: $e');
      rethrow;
    }
  }

  /// Get user's current QR code and subscription status
  Future<Map<String, dynamic>?> getUserQrCode(String userId) async {
    try {
      final response = await _client
          .from('user_qr_codes')
          .select('*')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      _logger.e('Error getting user QR code: $e');
      return null;
    }
  }

  /// Process manual payment and update QR code
  Future<bool> processManualPayment({
    required String userId,
    required String planType,
  }) async {
    try {
      // Validate plan type
      final validatedPlanType = _validatePlanType(planType);

      // Fetch user's name and surname
      final profile = await _client
          .from('profiles')
          .select('name, surname')
          .eq('id', userId)
          .single();

      final name = profile['name'] as String? ?? 'Unknown';
      final surname = profile['surname'] as String? ?? 'Unknown';

      // Generate new QR code
      final newQrCode = await QrCodeService().generateUniqueQrCode(userId);

      // Update QR code
      await _client.from('user_qr_codes').upsert({
        'user_id': userId,
        'qr_code': newQrCode,
        'name': name,
        'surname': surname,
        'is_active': true,
        'expires_at': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Update subscription
      await _client
          .from('subscriptions')
          .update({
            'plan_type': validatedPlanType,
            'current_period_start': DateTime.now().toIso8601String(),
            'current_period_end': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'next_payment_date': DateTime.now()
                .add(const Duration(days: 30))
                .toIso8601String(),
            'last_payment_date': DateTime.now().toIso8601String(),
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);

      // Record renewal
      await _client.from('subscription_renewals').insert({
        'subscription_id': (await _client
            .from('subscriptions')
            .select('id')
            .eq('user_id', userId)
            .single())['id'],
        'user_id': userId,
        'renewal_date': DateTime.now().toIso8601String(),
        'amount': _getPlanAmount(validatedPlanType),
        'status': 'success',
        'qr_code_updated': true,
      });

      return true;
    } catch (e) {
      _logger.e('Error processing manual payment: $e');
      return false;
    }
  }

  /// Get countdown time until subscription expires (based on calendar month)
  Duration getTimeUntilNextPayment(DateTime? subscriptionEndDate) {
    if (subscriptionEndDate == null) return Duration.zero;
    final now = DateTime.now();
    final difference = subscriptionEndDate.difference(now);
    return difference; // Return actual difference, including negative values
  }

  /// Start countdown timer for manual payment reminder
  void startCountdownTimer(VoidCallback onTick) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      onTick();
    });
  }

  /// Stop countdown timer
  void stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Check if subscription is expired and deactivate QR code
  Future<void> checkAndHandleExpiredSubscriptions() async {
    try {
      final expiredSubscriptions = await _client
          .from('subscriptions')
          .select('user_id')
          .eq('status', 'active')
          .lt('current_period_end', DateTime.now().toIso8601String());

      for (final sub in expiredSubscriptions) {
        // Deactivate QR code
        await _client
            .from('user_qr_codes')
            .update({
              'is_active': false,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', sub['user_id']);

        // Update subscription status
        await _client
            .from('subscriptions')
            .update({
              'status': 'expired',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', sub['user_id']);
      }
    } catch (e) {
      _logger.e('Error handling expired subscriptions: $e');
    }
  }

  /// Update subscription renewal preference
  Future<void> updateAutoRenewal(String userId, bool autoRenew) async {
    try {
      if (autoRenew) {
        // For enabling auto-renewal, we need payment method info
        // This should be called from the payment screen with payment details
        throw Exception(
          'Use enableAutoRenewal method with payment details to enable auto-renewal',
        );
      } else {
        // Disable auto-renewal
        await _client.rpc(
          'disable_auto_renewal',
          params: {'p_user_id': userId},
        );
      }
    } catch (e) {
      _logger.e('Error updating auto renewal: $e');
      rethrow;
    }
  }

  /// Enable auto-renewal with payment method
  Future<void> enableAutoRenewal({
    required String userId,
    required String paymentMethod,
    required String paymentMethodId,
  }) async {
    try {
      await _client.rpc(
        'enable_auto_renewal',
        params: {
          'p_user_id': userId,
          'p_payment_method': paymentMethod,
          'p_payment_method_id': paymentMethodId,
        },
      );
    } catch (e) {
      _logger.e('Error enabling auto renewal: $e');
      rethrow;
    }
  }

  /// Get subscription status and renewal information
  Future<Map<String, dynamic>?> getSubscriptionStatus(String userId) async {
    try {
      final response = await _client.rpc(
        'get_subscription_status',
        params: {'p_user_id': userId},
      );

      if (response != null && response.isNotEmpty) {
        final data = response[0] as Map<String, dynamic>;
        return {
          'has_active_qr': data['has_active_qr'] ?? false,
          'qr_expires_at': data['qr_expires_at'],
          'subscription_status': data['subscription_status'] ?? 'none',
          'auto_renew': data['auto_renew'] ?? false,
          'days_until_renewal': data['days_until_renewal'],
          'next_payment_date': data['next_payment_date'],
          'payment_overdue': data['payment_overdue'] ?? false,
          'subscription_end_date': data['subscription_end_date'],
        };
      }

      return null;
    } catch (e) {
      _logger.e('Error getting subscription status: $e');
      return null;
    }
  }

  double _getPlanAmount(String planType) {
    switch (planType) {
      case 'basic':
        return 99.00;
      case 'premium':
        return 199.00;
      case 'annual':
        return 1999.00;
      default:
        return 99.00;
    }
  }

  /// Dispose resources
  void dispose() {
    stopCountdownTimer();
  }

  /// Validate and normalize plan type to ensure it's one of the valid values
  String _validatePlanType(String planType) {
    const validPlanTypes = ['basic', 'premium', 'annual'];
    if (validPlanTypes.contains(planType.toLowerCase())) {
      return planType.toLowerCase();
    }
    // Default to 'basic' if invalid plan type is provided
    _logger.w('Warning: Invalid plan type "$planType", defaulting to "basic"');
    return 'basic';
  }
}
