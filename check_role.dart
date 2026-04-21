import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  const url = 'https://qdrotavcmmevhgveodcp.supabase.co';
  const anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkcm90YXZjbW1ldmhndmVvZGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjAxMzUsImV4cCI6MjA3MzA5NjEzNX0.dbEFbk8StiMbldSjvlMrFs8X3mCpNpGG3wdgxXg8mqo';

  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  try {
    // Query profiles table for the email
    final profileResponse = await client
        .from('profiles')
        .select('id, email, name, role, created_at')
        .eq('email', 'clydemflan@gmail.com');

    print('Profiles for clydemflan@gmail.com:');
    print(profileResponse);

    if (profileResponse.isNotEmpty) {
      final userId = profileResponse[0]['id'];

      // Query memberships table for the role
      final membershipResponse = await client
          .from('memberships')
          .select('role')
          .eq('user_id', userId);

      print('Memberships for member $userId:');
      print(membershipResponse);
    }
  } catch (e) {
    print('Error: $e');
  }
}
