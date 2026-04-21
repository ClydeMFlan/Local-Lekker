import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load(fileName: '.env.development');

  final url = dotenv.env['SUPABASE_URL']!;
  final serviceKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY']!;

  final supabase = SupabaseClient(url, serviceKey);

  final sql = '''
-- Fix admin deal image upload RLS policy
-- The issue is that the policy needs to properly check if:
-- 1. The authenticated user is an admin (has role='admin' in memberships)
-- 2. The business owner (trusted partner) has allow_admin_deal_creation = true
-- 3. The path matches deal_images/{trusted_partner_id}/...

-- Drop the existing policy
DROP POLICY IF EXISTS "Admins can manage deal images" ON storage.objects;

-- Create a new policy that properly checks admin permissions
CREATE POLICY "Admins can manage deal images" ON storage.objects
    FOR ALL USING (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1 
            FROM public.businesses b
            WHERE b.owner_member_id::text = (storage.foldername(name))[1]
              AND COALESCE(b.allow_admin_deal_creation, false) = true
              AND EXISTS (
                SELECT 1 
                FROM public.memberships m 
                WHERE m.user_id = auth.uid() 
                  AND m.role = 'admin'
              )
        )
    ) WITH CHECK (
        bucket_id = 'business-bills' AND
        name LIKE 'deal_images/%' AND
        EXISTS (
            SELECT 1 
            FROM public.businesses b
            WHERE b.owner_member_id::text = (storage.foldername(name))[1]
              AND COALESCE(b.allow_admin_deal_creation, false) = true
              AND EXISTS (
                SELECT 1 
                FROM public.memberships m 
                WHERE m.user_id = auth.uid() 
                  AND m.role = 'admin'
              )
        )
    );
''';

  try {
    print('Applying RLS policy fix...');
    await supabase.rpc('exec_sql', params: {'sql': sql});
    print('✓ RLS policy updated successfully!');
  } catch (e) {
    print('Error applying fix: $e');
    print('\nPlease run this SQL manually in your Supabase SQL editor:');
    print(sql);
  }
}
