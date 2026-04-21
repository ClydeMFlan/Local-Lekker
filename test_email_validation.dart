import 'package:local_lekker/services/supabase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  // Initialize Supabase
  final supabaseService = SupabaseService.instance;
  await supabaseService.init();

  // Test email validation
  print('Testing email validation for clydemflan@gmail.com...');
  final exists = await supabaseService.checkEmailExists('clydemflan@gmail.com');
  print('Email exists: $exists');

  // Test with a non-existent email
  print('Testing email validation for nonexistent@example.com...');
  final notExists = await supabaseService.checkEmailExists(
    'nonexistent@example.com',
  );
  print('Email exists: $notExists');
}
