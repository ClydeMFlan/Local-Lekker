import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

import '../features/admin/admin_dashboard_screen.dart';
import '../features/auth/welcome_page.dart'; // contains HomePage

/// Small, focused service to centralize member role resolution and routing.
class MemberService {
  final SupabaseClient supabase;
  final Logger _logger = Logger();

  MemberService(this.supabase);

  /// Resolve the current member's role via a secure RPC `get_my_role()`.
  ///
  /// Returns the role string (e.g. 'admin') or null when the role can't be
  /// resolved. This method intentionally prefers the RPC because RLS policies
  /// often prevent direct SELECTs from client-side code.
  Future<String?> getMemberRole() async {
    try {
      final role = await supabase.rpc('get_my_role') as String?;
      _logger.i('Resolved role: $role');
      return role;
    } catch (e) {
      _logger.e('MemberService.getMemberRole: RPC failed: $e');
      return null;
    }
  }

  /// Returns true if the current member resolves to admin.
  Future<bool> isAdmin() async {
    final role = await getMemberRole();
    return (role ?? '').toLowerCase() == 'admin';
  }

  /// Route the member to the correct screen based on resolved role.
  ///
  /// - admin -> AdminDashboardScreen
  /// - any other non-null role -> HomePage
  /// - null role -> RoleMissingScreen (a lightweight page that prompts the
  ///   member or logs the issue)
  Future<void> routeMemberByRole(BuildContext context) async {
    final member = supabase.auth.currentUser;
    if (member == null) {
      _logger.w('MemberService.routeMemberByRole: no member signed in');
      return;
    }

    final role = await getMemberRole();

    if (role?.toLowerCase() == 'admin') {
      try {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      } catch (e) {
        // Context might be invalid
      }
      return;
    }

    if (role != null) {
      try {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } catch (e) {
        // Context might be invalid
      }
      return;
    }

    // Role couldn't be resolved
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleMissingScreen()),
      );
    } catch (e) {
      // Context might be invalid
    }
  }
}

/// Simple page shown when a role cannot be determined. Keep this file
/// self-contained so callers don't need an extra import during migration.
class RoleMissingScreen extends StatelessWidget {
  const RoleMissingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'We could not determine your role. If you believe this is an error, please contact support.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small debug widget helper you can embed anywhere in the app while
/// diagnosing role resolution issues.
class RoleDebugButton extends StatelessWidget {
  const RoleDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final svc = MemberService(Supabase.instance.client);
        final role = await svc.getMemberRole();
        final member = Supabase.instance.client.auth.currentUser;

        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Role Check'),
            content: Text('Member: ${member?.email}\nRole: ${role ?? 'null'}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      child: const Text('Check Role'),
    );
  }
}
