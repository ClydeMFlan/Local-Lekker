// Test admin deletion functionality in the running app
// Add this to your admin screen or create a test button

import 'package:flutter/material.dart';
import 'package:local_lekker/services/admin_service.dart';
import 'package:local_lekker/services/supabase_service.dart';

class AdminDeletionTest extends StatefulWidget {
  const AdminDeletionTest({super.key});

  @override
  _AdminDeletionTestState createState() => _AdminDeletionTestState();
}

class _AdminDeletionTestState extends State<AdminDeletionTest> {
  String _testResult = '';
  bool _isLoading = false;

  Future<void> _testAdminDeletion() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing admin deletion...\n';
    });

    try {
      // First check if current user is admin
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _testResult += '❌ No authenticated user\n';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _testResult += '✅ User authenticated: ${currentUser.id}\n';
      });

      // Check admin status
      final adminService = AdminService();
      final isAdmin = await adminService.isAdmin(currentUser.id);

      setState(() {
        _testResult += isAdmin ? '✅ User is admin\n' : '❌ User is not admin\n';
      });

      if (!isAdmin) {
        setState(() {
          _testResult += 'Cannot test deletion - not an admin\n';
          _isLoading = false;
        });
        return;
      }

      // Get a trusted partner to test with
      final supabase = SupabaseService.instance.client;
      final tpResponse = await supabase
          .from('trusted_partners')
          .select('user_id, business_name')
          .limit(1);

      if (tpResponse.isEmpty) {
        setState(() {
          _testResult += '❌ No trusted partners found to test with\n';
          _isLoading = false;
        });
        return;
      }

      final tpResult = tpResponse.first;
      final testTpId = tpResult['user_id'] as String;
      final businessName = tpResult['business_name'] as String;

      setState(() {
        _testResult +=
            '🔍 Found test trusted partner: $businessName ($testTpId)\n';
        _testResult += '🧪 Starting deletion test...\n';
      });

      // Test the deletion
      final result = await adminService.deleteTrustedPartner(testTpId);

      setState(() {
        _testResult += '✅ Deletion successful!\n';
        _testResult += 'Result: $result\n';
        _testResult += '🎉 Admin deletion functionality is working!\n';
      });
    } catch (e) {
      setState(() {
        _testResult += '❌ Deletion failed: $e\n';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Deletion Test')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testAdminDeletion,
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Test Admin Deletion'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _testResult,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
