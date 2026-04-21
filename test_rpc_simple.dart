import 'package:supabase/supabase.dart';
import 'dart:io' show Platform;

void main() async {
  // Get environment variables
  final supabaseUrl = Platform.environment['SUPABASE_URL'];
  final supabaseAnonKey = Platform.environment['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    print(
      'Error: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set',
    );
    return;
  }

  // Initialize Supabase client
  final supabase = SupabaseClient(supabaseUrl, supabaseAnonKey);

  try {
    // Test the RPC function directly
    print('Testing RPC function check_email_exists...');
    final response = await supabase.rpc(
      'check_email_exists',
      params: {'user_email': 'clydemflan@gmail.com'},
    );

    print('RPC Response: $response');
    print('Response type: ${response.runtimeType}');

    // Also try to query the profiles table directly (this should fail due to RLS)
    print('Testing direct query to profiles table...');
    try {
      final directQuery = await supabase
          .from('profiles')
          .select('email, role, subscription')
          .eq('email', 'clydemflan@gmail.com')
          .single();

      print('Direct query result: $directQuery');
    } catch (e) {
      print('Direct query failed (expected due to RLS): $e');
    }
  } catch (e) {
    print('Error calling RPC function: $e');
  }
}
