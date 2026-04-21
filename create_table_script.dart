import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  final url = dotenv.env['SUPABASE_URL'] ?? 'http://localhost:54321';
  final anonKey =
      dotenv.env['SUPABASE_ANON_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  // SQL to create calibration_receipts table
  const createTableSQL = '''
-- Create calibration_receipts table for trusted partner receipt calibration
CREATE TABLE IF NOT EXISTS calibration_receipts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    business_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    business_name TEXT NOT NULL,
    receipt_url TEXT NOT NULL,
    text_blocks JSONB NOT NULL,
    layout_data JSONB NOT NULL,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Add indexes
CREATE INDEX IF NOT EXISTS idx_calibration_receipts_business_id ON calibration_receipts(business_id);
CREATE INDEX IF NOT EXISTS idx_calibration_receipts_active ON calibration_receipts(is_active);
CREATE INDEX IF NOT EXISTS idx_calibration_receipts_uploaded_at ON calibration_receipts(uploaded_at DESC);

-- Enable RLS
ALTER TABLE calibration_receipts ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Business owners can manage their calibration receipts" ON calibration_receipts;
DROP POLICY IF EXISTS "Members can view active calibration receipts" ON calibration_receipts;
DROP POLICY IF EXISTS "Service role can manage all calibration receipts" ON calibration_receipts;

-- Create policies
CREATE POLICY "Business owners can manage their calibration receipts"
ON calibration_receipts
FOR ALL
USING (business_id = auth.uid());

CREATE POLICY "Members can view active calibration receipts"
ON calibration_receipts
FOR SELECT
USING (is_active = true);

CREATE POLICY "Service role can manage all calibration receipts"
ON calibration_receipts
FOR ALL
USING (auth.role() = 'service_role');
''';

  try {
    // Try to execute the SQL using rpc
    final result = await client.rpc(
      'exec_sql',
      params: {'sql': createTableSQL},
    );
    print('Table creation result: $result');
    print('Calibration receipts table created successfully!');
  } catch (e) {
    print('Error creating table: $e');
    // Try alternative approach using direct postgres function
    try {
      await client.rpc('exec', params: {'query': createTableSQL});
      print('Table created using alternative method');
    } catch (e2) {
      print('Alternative method also failed: $e2');
    }
  }
}
