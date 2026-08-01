import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger();

Future<void> main() async {
  const supabaseUrl = 'https://qdrotavcmmevhgveodcp.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFkcm90YXZjbW1ldmhndmVvZGNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MjAxMzUsImV4cCI6MjA3MzA5NjEzNX0.dbEFbk8StiMbldSjvlMrFs8X3mCpNpGG3wdgxXg8mqo';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  try {
    logger.i('=== Starting Terms Reset and Sign-In Test ===');

    // Step 1: Reset terms for fuelbean@gmail.com
    logger.i('Step 1: Resetting partner_terms_accepted to false for fuelbean@gmail.com');

    // Get the user ID
    final authResponse = await client.auth.signInWithPassword(
      email: 'fuelbean@gmail.com',
      password: '000000',
    );
    final userId = authResponse.user?.id;
    logger.i('Found user ID: $userId');

    if (userId != null) {
      // Reset the terms
      await client.from('profiles').update({
        'partner_terms_accepted': false,
        'partner_terms_accepted_at': null,
      }).eq('id', userId);

      logger.i('✅ Successfully reset partner_terms_accepted to false');

      // Verify the reset
      final profile =
          await client.from('profiles').select().eq('id', userId).single();
      logger.i('Current profile state:');
      logger.i('  - partner_terms_accepted: ${profile['partner_terms_accepted']}');
      logger.i('  - partner_terms_accepted_at: ${profile['partner_terms_accepted_at']}');
    }

    logger.i('');
    logger.i('=== Test Setup Complete ===');
    logger.i('Now sign in to the app at http://localhost:8080');
    logger.i('Expected behavior: You should see the Trusted Partner Terms & Conditions screen');
    logger.i('===================================');

    // Keep the script alive for observation
    await Future.delayed(Duration(seconds: 5));
  } catch (e) {
    logger.e('Error: $e');
  }
}
