import 'package:flutter/material.dart';
import 'package:local_lekker/services/supabase_service.dart';
import 'package:local_lekker/services/payment_status_service.dart';
import 'package:local_lekker/services/paystack_service.dart';
import 'package:local_lekker/services/subscription_service.dart';
import 'package:local_lekker/features/auth/welcome_page.dart';
import 'package:local_lekker/features/auth/password_reset_page.dart';
import 'package:local_lekker/features/auth/trusted_partner_home_page.dart';
import 'package:local_lekker/features/auth/members_home_page.dart';
import 'package:local_lekker/features/admin/admin_dashboard_screen.dart';
import 'package:local_lekker/features/payments/payments_feature.dart';
import 'package:local_lekker/features/auth/business_profile_page.dart';
import 'package:local_lekker/features/trusted_partner/trusted_partner_terms_page.dart';
import 'package:local_lekker/features/member/member_terms_page.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  /// Check if user has valid profile data in Supabase
  Future<bool> _userHasValidProfile(String userId) async {
    try {
      // Check if user exists in profiles table
      final response = await SupabaseService.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (kDebugMode) {
        print(
          'NavigationService._userHasValidProfile: userId=$userId, hasProfile=${response.isNotEmpty}',
        );
      }
      return response.isNotEmpty;
    } catch (e) {
      // If we can't check the profile, assume it's invalid
      if (kDebugMode) {
        print(
          'NavigationService._userHasValidProfile ERROR: userId=$userId, error=$e',
        );
      }
      return false;
    }
  }

  /// Get subscription status for a user
  Future<String?> _getSubscriptionStatus(String userId) async {
    try {
      // First check the subscriptions table for active subscription
      final subscriptionResponse = await SupabaseService.instance.client
          .from('subscriptions')
          .select('status')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);

      if (subscriptionResponse.isNotEmpty) {
        return 'active';
      }

      // If no active subscription, check profile subscription field
      final profileResponse = await SupabaseService.instance.client
          .from('profiles')
          .select('subscription')
          .eq('id', userId)
          .order('created_at', ascending: false)
          .limit(1);

      if (profileResponse.isEmpty) {
        // Before returning pending, try to recover from interrupted payment
        final recovered = await _tryRecoverPendingPayment(userId);
        if (recovered) return 'active';
        return 'pending';
      }

      final status = profileResponse[0]['subscription'] as String? ?? 'pending';
      if (status != 'active') {
        // Before returning non-active, try to recover from interrupted payment
        final recovered = await _tryRecoverPendingPayment(userId);
        if (recovered) return 'active';
      }
      return status;
    } catch (e) {
      // If we can't check subscription status, assume it's pending
      if (kDebugMode) {
        print('NavigationService: Error checking subscription: $e');
      }
      return 'pending';
    }
  }

  /// Attempt to recover a payment that succeeded at Paystack but was not
  /// processed by the app (e.g. user lost signal or closed the app).
  /// Returns true if a successful payment was found and the subscription
  /// was activated.
  Future<bool> _tryRecoverPendingPayment(String userId) async {
    final logger = Logger();
    try {
      final paystackService = PaystackService();

      // STRATEGY 1: Check for a saved transaction reference (from current update onwards)
      final pendingTx = await PaymentStatusService()
          .getPendingTransactionReference(userId);

      if (pendingTx != null) {
        final reference = pendingTx['reference']!;
        final planType = pendingTx['planType'] ?? 'subscription';

        logger.i(
          'NavigationService: Found pending transaction ref=$reference, verifying with Paystack...',
        );

        final verifiedDetails = await paystackService.verifyTransaction(reference);

        if (verifiedDetails != null) {
          logger.i('NavigationService: Payment CONFIRMED via saved reference!');
          return await _activateRecoveredPayment(
            userId: userId,
            planType: planType,
            verifiedDetails: verifiedDetails,
            paystackService: paystackService,
            logger: logger,
          );
        } else {
          logger.w('NavigationService: Saved transaction ref not successful at Paystack');
        }
      }

      // STRATEGY 2: No saved reference (member paid before this update) —
      // search Paystack for recent successful transactions by email
      final user = SupabaseService.instance.getCurrentUser();
      final email = user?.email;
      if (email == null || email.isEmpty) return false;

      logger.i('NavigationService: No saved reference. Searching Paystack by email=$email...');

      final txData = await paystackService.findSuccessfulSubscriptionTransaction(email);
      if (txData == null) {
        logger.i('NavigationService: No successful Paystack transactions found for $email');
        return false;
      }

      // Verify this transaction belongs to this user via metadata
      final metadata = txData['metadata'] as Map<String, dynamic>? ?? {};
      final txUserId = metadata['user_id']?.toString();
      if (txUserId != null && txUserId != userId) {
        logger.w('NavigationService: Transaction user_id mismatch ($txUserId != $userId)');
        return false;
      }

      logger.i('NavigationService: Found successful payment at Paystack via email lookup! ref=${txData['reference']}');

      return await _activateRecoveredPayment(
        userId: userId,
        planType: 'subscription',
        verifiedDetails: txData,
        paystackService: paystackService,
        logger: logger,
      );
    } catch (e) {
      Logger().e('NavigationService: Error during payment recovery: $e');
      return false;
    }
  }

  /// Shared logic to activate a subscription from a recovered Paystack payment.
  Future<bool> _activateRecoveredPayment({
    required String userId,
    required String planType,
    required Map<String, dynamic> verifiedDetails,
    required PaystackService paystackService,
    required Logger logger,
  }) async {
    logger.i('NavigationService: Activating subscription from recovered payment...');

    if (planType == 'promotion_intro') {
      final metadata =
          verifiedDetails['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{};

      final promotionId = metadata['promotion_id']?.toString();
      final participantId = metadata['participant_id']?.toString();
      final freeMonths = int.tryParse(metadata['free_months']?.toString() ?? '') ?? 0;
      final initialChargeCents =
          int.tryParse(metadata['initial_charge_cents']?.toString() ?? '') ?? 100;
      final renewalChargeCents =
          int.tryParse(metadata['renewal_charge_cents']?.toString() ?? '') ?? 9900;
      final reference = verifiedDetails['reference']?.toString();

      if (promotionId == null || participantId == null) {
        logger.e('NavigationService: Missing promo metadata for recovered intro payment');
        return false;
      }

      final activated = await SubscriptionService().activateIntroCampaignSubscription(
        userId: userId,
        promotionId: promotionId,
        participantId: participantId,
        freeMonths: freeMonths,
        initialChargeCents: initialChargeCents,
        renewalChargeCents: renewalChargeCents,
        introChargeReference: reference,
      );

      if (activated) {
        await PaymentStatusService().clearPendingTransactionReference(userId);
        await PaymentStatusService().clearPendingPayment(userId);
      }
      return activated;
    }

    // Save card details if available
    try {
      final auth = verifiedDetails['authorization'] as Map<String, dynamic>?;
      if (auth != null) {
        final authorizationCode = auth['authorization_code'];
        if (authorizationCode != null && authorizationCode.toString().isNotEmpty) {
          final existing = await paystackService.getSavedPaymentMethods(userId);
          final shouldSetPrimary =
              existing.isEmpty || !existing.any((m) => m['is_primary'] == true);

          final cardDetails = {
            'card_type': auth['card_type'] ?? 'card',
            'last4': auth['last4'] ?? '****',
            'exp_month': auth['exp_month'],
            'exp_year': auth['exp_year'],
            'bank': auth['bank'],
            'brand': auth['brand'],
            'is_primary': shouldSetPrimary,
          };

          await paystackService.addPaymentMethod(userId, authorizationCode, cardDetails);
          if (shouldSetPrimary) {
            await paystackService.setPrimaryPaymentMethod(userId, authorizationCode);
          }
        }
      }

      // Save customer code
      final customer = verifiedDetails['customer'] as Map<String, dynamic>?;
      final customerCode = customer?['customer_code'] as String?;
      if (customerCode != null && customerCode.isNotEmpty) {
        await paystackService.savePaystackCustomerCode(
          userId: userId,
          customerCode: customerCode,
        );
      }
    } catch (e) {
      logger.w('NavigationService: Error saving card/customer during recovery: $e');
      // Continue - card saving is not critical for subscription activation
    }

    // Retrieve Paystack subscription code for webhook matching
    String? paystackSubscriptionCode;
    try {
      final customerCode = await paystackService.getPaystackCustomerCode(userId);
      if (customerCode != null && customerCode.isNotEmpty) {
        paystackSubscriptionCode = await paystackService.getCustomerSubscriptionCode(
          customerCodeOrEmail: customerCode,
        );
      }
    } catch (e) {
      logger.w('NavigationService: Could not retrieve subscription code during recovery: $e');
    }

    // Activate subscription
    final success = await SubscriptionService().processManualPayment(
      userId: userId,
      planType: planType,
      paystackSubscriptionCode: paystackSubscriptionCode,
    );

    if (success) {
      // Clear any pending references
      await PaymentStatusService().clearPendingTransactionReference(userId);
      await PaymentStatusService().clearPendingPayment(userId);
      logger.i('NavigationService: Payment recovery successful! Subscription activated.');
      return true;
    } else {
      logger.e('NavigationService: processManualPayment returned false during recovery');
      return false;
    }
  }

  /// Determine the appropriate initial screen based on member authentication and role
  Future<Widget> getInitialScreen() async {
    final logger = Logger();

    // FIRST: Check if user has an active password recovery session
    try {
      logger.i('NavigationService: Checking for active recovery sessions...');
      final response = await SupabaseService.instance.client
          .from('recovery_sessions')
          .select()
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .limit(1);

      logger.i(
        'NavigationService: Recovery session query returned: ${response.length} results',
      );

      if (response.isNotEmpty) {
        logger.i(
          'NavigationService: Active recovery session found - showing PasswordResetPage',
        );
        final recoveryData = response[0];
        final token = recoveryData['token'] ?? '';

        // Mark as used
        try {
          await SupabaseService.instance.client
              .from('recovery_sessions')
              .update({'used': true})
              .eq('id', recoveryData['id']);
          logger.i('NavigationService: Recovery session marked as used');
        } catch (e) {
          logger.w('Failed to mark recovery session as used: $e');
        }

        // Return PasswordResetPage
        return PasswordResetPage(accessToken: token, refreshToken: null);
      }
    } catch (e) {
      final logger = Logger();
      logger.e('NavigationService: Error checking recovery session: $e');
      // Continue with normal auth flow
    }

    // Check authentication status
    try {
      final member = SupabaseService.instance.getCurrentUser();

      if (member == null) {
        // Member not authenticated, show welcome page
        return const WelcomePage();
      }

      // Check if user is deactivated before proceeding
      try {
        final profileData = await SupabaseService.instance.client
            .from('profiles')
            .select('is_deactivated')
            .eq('id', member.id)
            .maybeSingle();

        if (profileData != null && profileData['is_deactivated'] == true) {
          logger.w(
            'NavigationService: User is deactivated - redirecting to reactivation flow',
          );
          return const PaymentRequiredScreen(isReactivation: true);
        }
      } catch (e) {
        logger.w('NavigationService: Error checking deactivation status: $e');
        // Continue with normal flow if check fails
      }

      // Check if user has valid profile data
      final hasProfile = await _userHasValidProfile(member.id);
      if (!hasProfile) {
        // User is authenticated but has no profile data
        // For admin users, don't sign them out - they might have RLS issues
        // Just log the error and try to proceed with role check
        if (kDebugMode) {
          print(
            'NavigationService.getInitialScreen: WARNING - Profile check failed for user ${member.id}',
          );
        }

        // Try to get role anyway - admin might be accessible via getUserRole
        final role = await SupabaseService.instance.getUserRole(
          userId: member.id,
        );

        if (role == 'admin') {
          if (kDebugMode) {
            print(
              'NavigationService.getInitialScreen: User is admin, proceeding despite profile check failure',
            );
          }
          return const AdminDashboardScreen();
        }

        // For non-admin users, sign them out and show welcome
        if (kDebugMode) {
          print(
            'NavigationService.getInitialScreen: Non-admin user with no profile - signing out',
          );
        }
        await SupabaseService.instance.signOut();
        return const WelcomePage();
      }

      // Member is authenticated and has profile, check their role
      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );

      if (kDebugMode) {
        print(
          'NavigationService.getInitialScreen: userId=${member.id}, role=$role',
        );
      }

      // Route based on member role
      switch (role?.toLowerCase()) {
        case 'admin':
          if (kDebugMode) {
            print(
              'NavigationService.getInitialScreen: Routing to AdminDashboardScreen',
            );
          }
          return const AdminDashboardScreen();

        case 'trusted_partner':
          // If trusted partner has not completed business setup, force them to BusinessProfilePage
          final isComplete = await SupabaseService.instance
              .isBusinessProfileComplete(member.id);
          if (!isComplete) {
            return const BusinessProfilePage();
          }
          // Check partner terms acceptance before proceeding; if also a member, ensure member terms too
          final profile = await SupabaseService.instance.getUserProfile(
            userId: member.id,
          );
          final partnerAccepted = (profile?['partner_terms_accepted'] == true);
          if (!partnerAccepted) {
            return const TrustedPartnerTermsPage();
          }
          // If this trusted partner is also a member, require member terms acceptance
          final bool isAlsoMember = profile?['is_tp_member'] == true;
          if (isAlsoMember) {
            final memberAccepted = await SupabaseService.instance
                .hasMemberAcceptedTerms(member.id);
            if (!memberAccepted) {
              return const MemberTermsPage();
            }
          }
          return const TrustedPartnerHomePage();

        case 'member':
        default:
          // CRITICAL: Always require member terms acceptance BEFORE payment screens
          final memberAccepted = await SupabaseService.instance
              .hasMemberAcceptedTerms(member.id);
          if (!memberAccepted) {
            return const MemberTermsPage();
          }
          // After terms acceptance, check subscription status
          final subscriptionStatus = await _getSubscriptionStatus(member.id);
          if (subscriptionStatus == 'active') {
            return const MembersHomePage();
          }
          // Only show payment screen after terms are accepted
          return const PaymentRequiredScreen();
      }
    } catch (e) {
      // On error, fall back to welcome page
      if (kDebugMode) {
        print('NavigationService: Error determining initial screen: $e');
      }
      return const WelcomePage();
    }
  }

  /// Navigate to appropriate home page after successful authentication
  Future<void> navigateToHomeAfterAuth(BuildContext context) async {
    try {
      final member = SupabaseService.instance.getCurrentUser();
      if (member == null) {
        // No authenticated member, go to welcome
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
        return;
      }

      // Check if user has valid profile data
      final hasProfile = await _userHasValidProfile(member.id);
      if (!hasProfile) {
        // User is authenticated but has no profile data
        // For admin users, don't sign them out - they might have RLS issues
        // Try to get role first
        final role = await SupabaseService.instance.getUserRole(
          userId: member.id,
        );

        if (role == 'admin') {
          if (kDebugMode) {
            print(
              'NavigationService.navigateToHomeAfterAuth: Admin user, proceeding despite profile check failure',
            );
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
          );
          return;
        }

        // For non-admin users, sign them out and show welcome
        if (kDebugMode) {
          print(
            'NavigationService.navigateToHomeAfterAuth: Non-admin user with no profile - signing out',
          );
        }
        await SupabaseService.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
        return;
      }

      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );
      Widget homePage;

      switch (role?.toLowerCase()) {
        case 'admin':
          homePage = const AdminDashboardScreen();
          break;
        case 'trusted_partner':
          // Check business completion and route accordingly
          final isComplete = await SupabaseService.instance
              .isBusinessProfileComplete(member.id);
          if (!isComplete) {
            homePage = const BusinessProfilePage();
          } else {
            final profile = await SupabaseService.instance.getUserProfile(
              userId: member.id,
            );
            final accepted = (profile?['partner_terms_accepted'] == true);
            homePage = accepted
                ? const TrustedPartnerHomePage()
                : const TrustedPartnerTermsPage();
          }
          break;
        case 'member':
        default:
          // Always gate on member terms first
          final memberAccepted = await SupabaseService.instance
              .hasMemberAcceptedTerms(member.id);
          if (!memberAccepted) {
            homePage = const MemberTermsPage();
            break;
          }
          final subscriptionStatus = await _getSubscriptionStatus(member.id);
          homePage = subscriptionStatus == 'active'
              ? const MembersHomePage()
              : const PaymentRequiredScreen();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homePage),
      );
    } catch (e) {
      // Fallback to welcome page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomePage()),
      );
    }
  }

  /// Navigate to home page after successful payment
  /// Navigate to appropriate home page after successful payment
  Future<void> navigateToHomeAfterPayment(BuildContext context) async {
    try {
      final member = SupabaseService.instance.getCurrentUser();
      if (member == null) {
        // No authenticated member, go to welcome
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
        return;
      }

      // Check if user has valid profile data
      final hasProfile = await _userHasValidProfile(member.id);
      if (!hasProfile) {
        // User is authenticated but has no profile data
        // For admin users, don't sign them out - they might have RLS issues
        // Try to get role first
        final role = await SupabaseService.instance.getUserRole(
          userId: member.id,
        );

        if (role == 'admin') {
          if (kDebugMode) {
            print(
              'NavigationService.navigateToHomeAfterPayment: Admin user, proceeding despite profile check failure',
            );
          }
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
          );
          return;
        }

        // For non-admin users, sign them out and show welcome
        if (kDebugMode) {
          print(
            'NavigationService.navigateToHomeAfterPayment: Non-admin user with no profile - signing out',
          );
        }
        await SupabaseService.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WelcomePage()),
        );
        return;
      }

      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );
      Widget homePage;

      switch (role?.toLowerCase()) {
        case 'admin':
          homePage = const AdminDashboardScreen();
          break;
        case 'trusted_partner':
          // On payment flow routing, also respect business completion
          final isComplete = await SupabaseService.instance
              .isBusinessProfileComplete(member.id);
          if (!isComplete) {
            homePage = const BusinessProfilePage();
          } else {
            final profile = await SupabaseService.instance.getUserProfile(
              userId: member.id,
            );
            final accepted = (profile?['partner_terms_accepted'] == true);
            homePage = accepted
                ? const TrustedPartnerHomePage()
                : const TrustedPartnerTermsPage();
          }
          break;
        case 'member':
        default:
          // On payment completion, still enforce member terms acceptance if somehow not yet accepted
          final memberAccepted = await SupabaseService.instance
              .hasMemberAcceptedTerms(member.id);
          if (!memberAccepted) {
            homePage = const MemberTermsPage();
          } else {
            // Verify subscription is truly active before showing home page.
            // If processManualPayment failed but user was navigated here
            // anyway, redirect back to PaymentRequiredScreen instead of
            // letting the user land on a broken home page.
            final subStatus = await _getSubscriptionStatus(member.id);
            homePage = subStatus == 'active'
                ? const MembersHomePage()
                : const PaymentRequiredScreen();
          }
          break;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => homePage),
        (route) => false,
      );
    } catch (e) {
      // On error, fall back to member home page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MembersHomePage()),
        (route) => false,
      );
    }
  }
}
