import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final supabase = Supabase.instance.client;

  print('🔍 Checking trusted_partners table...\n');

  try {
    // 1. Check table structure
    print('📋 TABLE STRUCTURE:');
    final structureQuery = '''
      SELECT
          column_name,
          data_type,
          is_nullable,
          column_default
      FROM information_schema.columns
      WHERE table_name = 'trusted_partners'
      ORDER BY ordinal_position;
    ''';

    final structureResult = await supabase.rpc(
      'execute_sql',
      params: {'query': structureQuery},
    );
    print(structureResult);
    print('\n');

    // 2. Check current contents
    print('📊 TABLE CONTENTS:');
    final contentResult = await supabase
        .from('trusted_partners')
        .select(
          'id, user_id, business_id, business_name, paystack_recipient_code, paystack_subaccount_id, created_at, updated_at',
        )
        .order('created_at', ascending: false);

    print('Found ${contentResult.length} records:');
    for (var record in contentResult) {
      print('  - ID: ${record['id']}');
      print('    User ID: ${record['user_id']}');
      print('    Business ID: ${record['business_id']}');
      print('    Business Name: ${record['business_name']}');
      print('    Recipient Code: ${record['paystack_recipient_code']}');
      print('    Subaccount ID: ${record['paystack_subaccount_id']}');
      print('    Created: ${record['created_at']}');
      print('    Updated: ${record['updated_at']}\n');
    }

    // 3. Check record counts
    print('📈 RECORD COUNTS:');
    final allRecords = await supabase
        .from('trusted_partners')
        .select('id, paystack_recipient_code');
    final totalCount = allRecords.length;
    final withRecipientCode = allRecords
        .where((r) => r['paystack_recipient_code'] != null)
        .length;

    print('Total records: $totalCount');
    print('Records with recipient code: $withRecipientCode');
    print('Records without recipient code: ${totalCount - withRecipientCode}');

    // 4. Check for duplicates
    print('\n🔍 DUPLICATE CHECK:');
    final allUserRecords = await supabase
        .from('trusted_partners')
        .select('user_id');
    final userIds = allUserRecords.map((r) => r['user_id']).toList();
    final uniqueUserIds = userIds.toSet();
    print('Total user_ids: ${userIds.length}');
    print('Unique user_ids: ${uniqueUserIds.length}');
    if (userIds.length != uniqueUserIds.length) {
      print('⚠️  WARNING: Duplicate user_ids found!');
    } else {
      print('✅ No duplicate user_ids');
    }
  } catch (e) {
    print('❌ Error checking trusted_partners table: $e');
  }
}
