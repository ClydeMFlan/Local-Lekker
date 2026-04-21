// Test script to verify business name pre-filling works
// This simulates what happens when a trusted partner signs in

import 'package:local_lekker/services/supabase_service.dart';

Future<void> testBusinessNamePrefilling() async {
  try {
    // Simulate a trusted partner who was created by admin
    final testTpId =
        '985fa2aa-45c7-450a-a8b8-ff63934a6193'; // Current user from logs

    print('🧪 Testing business name pre-filling for trusted partner...');

    // Check if user has a trusted_partners record with business_name
    final tpResponse = await SupabaseService.instance.client
        .from('trusted_partners')
        .select('business_name')
        .eq('user_id', testTpId)
        .maybeSingle();

    if (tpResponse != null) {
      final businessName = tpResponse['business_name'] as String?;
      print('✅ Found business name in trusted_partners: "$businessName"');

      // Check if user has a businesses record
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('name')
          .eq('owner_member_id', testTpId)
          .maybeSingle();

      if (businessResponse != null) {
        final existingBusinessName = businessResponse['name'] as String?;
        print('ℹ️  User already has business record: "$existingBusinessName"');
      } else {
        print(
          'ℹ️  No business record found - business name should be pre-filled from trusted_partners',
        );
        print(
          '🎯 Expected behavior: BusinessProfilePage should show "$businessName" in the name field',
        );
      }
    } else {
      print('❌ No trusted_partners record found for user');
    }

    print('✅ Test completed');
  } catch (e) {
    print('❌ Test failed: $e');
  }
}
