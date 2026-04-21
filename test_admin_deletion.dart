// Test script to verify admin deletion works
// Add this to your Flutter app for testing

import 'package:local_lekker/services/admin_service.dart';

void testAdminDeletion() async {
  try {
    // Get a test trusted partner ID (replace with real ID)
    final testTpId = 'some-trusted-partner-user-id';

    print('Testing trusted partner deletion...');

    // Create AdminService instance
    final adminService = AdminService();

    // This should now work completely
    await adminService.deleteTrustedPartner(testTpId);

    print('✅ Trusted partner deletion successful!');
    print('✅ Auth user should be deleted');
    print('✅ All data should be cleaned up');
  } catch (e) {
    print('❌ Deletion failed: $e');
  }
}
