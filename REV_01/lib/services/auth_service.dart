import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:local_lekker/features/admin/admin_dashboard_screen.dart';
import 'package:local_lekker/features/auth/welcome_page.dart';
import 'package:local_lekker/services/supabase_service.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  late final SupabaseClient supabase = Supabase.instance.client;
  final Logger _logger = Logger();

  /// Request an OTP for [email]. This simply forwards to Supabase and
  /// returns when the request completes. Verification is handled elsewhere.
  Future<void> signInWithOtp(String email) async {
    await supabase.auth.signInWithOtp(email: email);
  }

  /// Fetches the current user's role from the `profiles` table.
  /// Fetches the current user's role by looking up the `memberships` table
  /// (memberships.user_id = auth user id). Returns null if not found.
  Future<String?> getUserRole({String? userId}) async {
    // Delegate to the centralized SupabaseService implementation so the
    // membership/profile/RPC fallback logic stays in one place.
    return SupabaseService.instance.getUserRole(userId: userId);
  }

  /// Helper that checks role and routes accordingly. Extracted so callers
  /// can reuse the exact role-check + navigation behavior.
  Future<void> checkRoleAndRoute({required BuildContext context}) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not signed in')));
      }
      return;
    }

    final role = await getUserRole();
    if ((role ?? '').toLowerCase() == 'admin') {
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      }
    } else {
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    }
  }

  /// Combined sign-in (OTP) + role lookup + navigation helper.
  ///
  /// - Requests an OTP (may only send an email/magic link).
  /// - If a session exists immediately, looks up `memberships.role` by
  ///   `user_id` and navigates to the admin dashboard for admins or the
  ///   standard `HomePage` otherwise.
  /// - Shows SnackBars for common error states.
  Future<void> signInAndRoute({
    required BuildContext context,
    required String email,
  }) async {
    try {
      // Request OTP. This may only send the email and return before the
      // user has confirmed the OTP or clicked a magic link.
      await supabase.auth.signInWithOtp(email: email);

      // Check if a session exists now. If not, prompt the user to confirm
      // the OTP/magic link and return early.
      final user = supabase.auth.currentUser;
      if (user == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('OTP sent. Please confirm the code to continue.'),
            ),
          );
        }
        return;
      }

      // Lookup role from memberships table using user_id
      String? role;
      try {
        final roleRes = await supabase
            .from('memberships')
            .select('role')
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();

        if (roleRes is Map<String, dynamic> && roleRes['role'] != null) {
          role = roleRes['role'].toString();
        }
      } catch (e) {
        if (e.toString().contains('infinite recursion detected in policy')) {
          _logger.w(
            'Infinite recursion in memberships policy detected, skipping role lookup',
          );
          // role will remain null, which will trigger the default navigation
        } else {
          _logger.e('memberships lookup failed: $e');
          rethrow;
        }
      }

      // Route based on role. Use pushReplacement to avoid leaving the
      // sign-in screen on the stack.
      if ((role ?? '').toLowerCase() == 'admin') {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
          );
        }
      } else {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
