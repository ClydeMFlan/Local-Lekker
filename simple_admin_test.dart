// ignore_for_file: undefined_identifier, undefined_function, unused_element, unused_import, undefined_prefixed_name

// Simple test function to add to your existing admin screen
// Add this method to your admin screen's state class

Future<void> testAdminDeletion() async {
  try {
    // Show loading
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Testing admin deletion...')));

    // Check if current user is admin
    final currentUser = await SupabaseService.instance.getCurrentUser();
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ No authenticated user')));
      return;
    }

    final adminService = AdminService();
    final isAdmin = await adminService.isAdmin(currentUser.id);

    if (!isAdmin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Current user is not admin')));
      return;
    }

    // Get a trusted partner to test with
    final supabase = SupabaseService.instance.client;
    final tpResponse = await supabase
        .from('trusted_partners')
        .select('user_id, business_name')
        .limit(1);

    if (tpResponse.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ No trusted partners found to test with')),
      );
      return;
    }

    final tpResult = tpResponse.first;
    final testTpId = tpResult['user_id'] as String;
    final businessName = tpResult['business_name'] as String;

    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test Deletion'),
        content: Text(
          'Delete trusted partner: $businessName?\n\nThis will test the complete deletion including auth user removal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform deletion
    final result = await adminService.deleteTrustedPartner(testTpId);

    // Show success
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Deletion successful! Auth user removed.')),
    );

    print('Admin deletion test successful: $result');
  } catch (e) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('❌ Deletion failed: $e')));
    print('Admin deletion test failed: $e');
  }
}

// Add this button to your admin screen:
// ElevatedButton(
//   onPressed: testAdminDeletion,
//   child: Text('Test Admin Deletion'),
// )
