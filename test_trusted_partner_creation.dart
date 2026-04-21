// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

/// Developer-only harness to validate trusted partner creation flows.
/// This stub keeps analyzer happy while making it clear the feature
/// is intentionally disabled in production builds.
class TestTrustedPartnerCreation extends StatefulWidget {
  const TestTrustedPartnerCreation({super.key});

  @override
  State<TestTrustedPartnerCreation> createState() =>
      _TestTrustedPartnerCreationState();
}

class _TestTrustedPartnerCreationState
    extends State<TestTrustedPartnerCreation> {
  final Logger _logger = Logger();
  String _testResult = 'Not tested yet';
  bool _isLoading = false;

  Future<void> _runTest() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Running test stub...';
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final generatedEmail = 'test_tp_$timestamp@example.com';
      _logger.i('Stub trusted partner creation for $generatedEmail');

      // Intentionally stubbed: the real signup flow should use admin tools.
      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        _testResult = '✅ Stub completed for $generatedEmail';
      });
    } catch (e) {
      _logger.e('Stub failed: $e');
      setState(() {
        _testResult = '❌ Stub failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Trusted Partner Creation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This stub simulates trusted partner creation. Replace with the real admin test when ready.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _runTest,
              child: _isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Run Stub'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Result:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                _testResult,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
