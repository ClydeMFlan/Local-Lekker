import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Prefer development env for service-role ops; fallback to .env if needed.
  try {
    await dotenv.load(fileName: '.env.development');
  } catch (_) {
    await dotenv.load();
  }

  final url = dotenv.env['SUPABASE_URL'];
  final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in env file.');
    exitCode = 1;
    return;
  }

  final supabase = SupabaseClient(url, serviceKey);

  final migrationPath =
      'supabase/migrations/20260618101000_cleanup_deal_image_storage_policies.sql';
  final migrationSql = File(migrationPath).readAsStringSync();

  try {
    stdout.writeln('Applying migration: $migrationPath');
    final applyResult = await supabase.rpc('exec_sql', params: {'sql': migrationSql});
    stdout.writeln('Migration apply result: ${jsonEncode(applyResult)}');

    // Verification 1: list canonical deal image policies after apply.
    const verifyPoliciesSql = '''
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

    final policyResult =
        await supabase.rpc('exec_sql', params: {'sql': verifyPoliciesSql});
    stdout.writeln('Policy verification result: ${jsonEncode(policyResult)}');

    // Verification 2: ensure member_terms_accepted_status exists (final drift closure check).
    const verifyTermsSql = '''
SELECT
  p.proname,
  pg_get_function_identity_arguments(p.oid) AS args,
  p.prosecdef AS security_definer,
  md5(pg_get_functiondef(p.oid)) AS function_md5
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'member_terms_accepted_status';
''';

    final termsResult =
        await supabase.rpc('exec_sql', params: {'sql': verifyTermsSql});
    stdout.writeln('Terms RPC verification result: ${jsonEncode(termsResult)}');

    stdout.writeln('✓ Migration + verification completed');
  } catch (e) {
    stderr.writeln('Migration execution failed: $e');
    exitCode = 1;
  }
}
