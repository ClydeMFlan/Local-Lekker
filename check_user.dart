import 'dart:io';
import 'package:supabase/supabase.dart';

// Simple .env parser
Map<String, String> loadEnvFile(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};

  final lines = file.readAsLinesSync();
  final env = <String, String>{};

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

    final parts = trimmed.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim();
      env[key] = value;
    }
  }

  return env;
}

void main() async {
  // Load environment variables from .env file
  final env = loadEnvFile('.env');
  final supabaseUrl = env['SUPABASE_URL'];
  final supabaseKey = env['SUPABASE_ANON_KEY'];

  print('SUPABASE_URL: ${supabaseUrl != null ? "Found" : "Not found"}');
  print(
    'SUPABASE_ANON_KEY: ${supabaseKey != null ? "Found (${supabaseKey.length} chars)" : "Not found"}',
  );

  if (supabaseUrl == null || supabaseKey == null) {
    print('Missing required environment variables');
    return;
  }

  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    print('\n=== Checking user thecraftsmanel@gmail.com ===');

    // Check the specific user
    final profiles = await supabase
        .from('profiles')
        .select(
          'id, email, name, surname, role, admin_created, password_set, created_at, updated_at',
        )
        .eq('email', 'thecraftsmanel@gmail.com');

    print(
      'Found ${profiles.length} profiles with email thecraftsmanel@gmail.com',
    );

    for (final profile in profiles) {
      print('Profile ID: ${profile['id']}');
      print('Email: ${profile['email']}');
      print('Name: ${profile['name']}');
      print('Surname: ${profile['surname']}');
      print('Role: ${profile['role']}');
      print('Admin Created: ${profile['admin_created']}');
      print('Password Set: ${profile['password_set']}');
      print('Created At: ${profile['created_at']}');
      print('Updated At: ${profile['updated_at']}');
      print('---');
    }

    if (profiles.isNotEmpty) {
      // Also check trusted_partners
      final userId = profiles[0]['id'];
      final trustedPartners = await supabase
          .from('trusted_partners')
          .select('user_id, business_name, created_at')
          .eq('user_id', userId);

      print('\n=== Trusted Partners Record ===');
      print('Found ${trustedPartners.length} trusted partner records');

      for (final tp in trustedPartners) {
        print('User ID: ${tp['user_id']}');
        print('Business Name: ${tp['business_name']}');
        print('Created At: ${tp['created_at']}');
      }
    } else {
      print('No profiles found with that email address.');
    }
  } catch (e) {
    print('Error querying database: $e');
  }
}
