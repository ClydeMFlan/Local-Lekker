import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:local_lekker/services/supabase_service.dart';
import 'package:local_lekker/features/auth/welcome_page.dart';
import 'package:local_lekker/features/auth/trusted_partner_home_page.dart';
import 'package:local_lekker/features/auth/user_home_page.dart';
import 'package:local_lekker/features/auth/banking_setup_page.dart';

class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();
  final Logger _logger = Logger();

  /// Determine the appropriate initial screen based on member authentication and role
  Future<Widget> getInitialScreen() async {
    _logger.i('Starting initial screen determination');

    // Check authentication status
    try {
      final member = SupabaseService.instance.getCurrentUser();

      if (member == null) {
        // Member not authenticated, show welcome page
        _logger.i('No authenticated member, showing welcome page');
        return const WelcomePage();
      }

      // Member is authenticated, check their role
      _logger.i('Member authenticated (${member.email}), checking role...');

      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );
      _logger.i('Member role determined: ${role ?? 'null'}');

      // Route based on member role
      switch (role?.toLowerCase()) {
        case 'admin':
          // TODO: Fix admin dashboard import
          return const UserHomePage(); // Temporary fallback

        case 'trusted_partner':
          _logger.i('Routing trusted partner to TrustedPartnerHomePage');
          return const TrustedPartnerHomePage();

        case 'member':
        default:
          _logger.i('Routing member to MemberHomePage');
          return const UserHomePage(); // Keeping same page, just renamed conceptually
      }
    } catch (e) {
      _logger.e('Error getting initial screen: $e');
      // On error, fall back to welcome page
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

      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );
      Widget homePage;

      switch (role?.toLowerCase()) {
        case 'admin':
          homePage = const UserHomePage(); // TODO: Fix admin dashboard
          break;
        case 'trusted_partner':
          // Check if trusted partner has completed banking setup
          final hasBankingSetup = await _checkTrustedPartnerBankingSetup(
            member.id,
          );
          if (!hasBankingSetup) {
            homePage = const BankingSetupPage();
          } else {
            homePage = const TrustedPartnerHomePage();
          }
          break;
        case 'member':
        default:
          homePage = const UserHomePage();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homePage),
      );
    } catch (e) {
      _logger.e('Error navigating to home: $e');
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

      final role = await SupabaseService.instance.getUserRole(
        userId: member.id,
      );
      Widget homePage;

      switch (role?.toLowerCase()) {
        case 'admin':
          homePage = const UserHomePage(); // TODO: Fix admin dashboard
          break;
        case 'trusted_partner':
          homePage = const TrustedPartnerHomePage();
          break;
        case 'member':
        default:
          homePage = const UserHomePage();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homePage),
      );
    } catch (e) {
      _logger.e('Error navigating to home after payment: $e');
      // On error, fall back to member home page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const UserHomePage()),
      );
    }
  }

  /// Helper method to check if trusted partner has completed banking setup
  Future<bool> _checkTrustedPartnerBankingSetup(String userId) async {
    try {
      final businessData = await SupabaseService.instance.client
          .from('trusted_partners')
          .select('paystack_subaccount_id')
          .eq('user_id', userId)
          .maybeSingle();

      return businessData != null &&
          businessData['paystack_subaccount_id'] != null &&
          businessData['paystack_subaccount_id'].toString().isNotEmpty;
    } catch (e) {
      _logger.e('Error checking banking setup: $e');
      return false; // Default to requiring setup on error
    }
  }
}
