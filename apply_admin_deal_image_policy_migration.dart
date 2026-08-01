import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  try {
    await dotenv.load(fileName: '.env.development');
  } catch (_) {
    await dotenv.load();
  }

  final url = dotenv.env['SUPABASE_URL'];
  final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || url.isEmpty || serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.');
    exitCode = 1;
    return;
  }

  final migrationPath =
      'supabase/migrations/20260618202500_fix_admin_deal_image_upload_policy.sql';
  final migrationSql = File(migrationPath).readAsStringSync();
  final supabase = SupabaseClient(url, serviceKey);

  try {
    stdout.writeln('Applying migration: $migrationPath');
    final applyResult =
        await supabase.rpc('exec_sql', params: {'sql': migrationSql});
    stdout.writeln('Apply result: ${jsonEncode(applyResult)}');

    const verifySql = '''
SELECT schemaname, tablename, policyname, cmd
FROM pg_policies
WHERE schemaname = 'storage'
  AND tablename = 'objects'
  AND (
    policyname ILIKE '%deal image%'
    OR policyname ILIKE '%deal_images%'
  )
ORDER BY policyname, cmd;
''';

    final verifyResult =
        await supabase.rpc('exec_sql', params: {'sql': verifySql});
    stdout.writeln('Policy verification: ${jsonEncode(verifyResult)}');
    stdout.writeln('Done.');
  } catch (e) {
    stderr.writeln('Failed to apply migration via exec_sql RPC: $e');
    exitCode = 1;
  }
}
