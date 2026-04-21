import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final supabase = Supabase.instance.client;

  /// Fetch the admin dashboard via RPC and normalize to a Map.
  Future<Map<String, dynamic>> fetchDashboard() async {
    try {
      dynamic res;
      // Prefer a secure SECURITY DEFINER RPC if it's available. Fall back to
      // the older RPC name for backwards compatibility.
      try {
        res = await supabase.rpc('secure_get_admin_dashboard').select();
      } catch (_) {
        res = await supabase.rpc('get_admin_dashboard').select();
      }

      // If RPC returns a list (common), take the first element
      if (res is List && res.isNotEmpty) {
        final first = res.first;
        if (first is Map) return Map<String, dynamic>.from(first);
      }

      if (res is Map) return Map<String, dynamic>.from(res);

      // Fallback empty map
      return {};
    } catch (e) {
      throw Exception('Failed to fetch admin dashboard: $e');
    }
  }
}
