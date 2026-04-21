import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  // Load environment variables
  final envFile = File('.env');
  final envContent = await envFile.readAsString();
  final envLines = envContent.split('\n');

  String supabaseUrl = '';
  String supabaseAnonKey = '';

  for (final line in envLines) {
    if (line.startsWith('SUPABASE_URL=')) {
      supabaseUrl = line.split('=')[1];
    } else if (line.startsWith('SUPABASE_ANON_KEY=')) {
      supabaseAnonKey = line.split('=')[1];
    }
  }

  // Initialize Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  final supabase = Supabase.instance.client;

  // Check for existing card details
  final userId = '78e67dc8-583b-4fe0-84e6-aa4d0c55a92e';
  print('Checking for existing card details for user: $userId');

  try {
    final response = await supabase
        .from('members_card_details')
        .select(
          'id, user_id, authorization_code, masked_card_number, created_at',
        )
        .eq('user_id', userId);

    if (response.isEmpty) {
      print('No existing card details found for this user.');
      print('You need to save a card first before testing verifyStoredCard.');
    } else {
      print('Found ${response.length} card detail(s):');
      for (final card in response) {
        print('- ID: ${card['id']}');
        print('  Authorization Code: ${card['authorization_code']}');
        print('  Masked Card: ${card['masked_card_number']}');
        print('  Created: ${card['created_at']}');
        print('');

        // Test verifyStoredCard if authorization code exists
        final authCode = card['authorization_code'];
        if (authCode != null && authCode.isNotEmpty) {
          print('Testing verifyStoredCard with authorization code: $authCode');

          // Simulate the verifyStoredCard logic
          final verifyUrl =
              'https://api.paystack.co/transaction/verify/$authCode';
          print('Would call Paystack API: $verifyUrl');

          // In development mode, this would return a simulated response
          print(
            'Expected response in development mode: {"status": true, "message": "Verification successful", "data": {"status": "success"}}',
          );
        } else {
          print('No authorization code found for this card.');
        }
      }
    }
  } catch (e) {
    print('Error querying database: $e');
  }
}
