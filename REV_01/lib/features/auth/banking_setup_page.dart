import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/navigation_service.dart';
import '../../services/supabase_service.dart';

class BankingSetupPage extends StatefulWidget {
  const BankingSetupPage({super.key});

  @override
  State<BankingSetupPage> createState() => _BankingSetupPageState();
}

class _BankingSetupPageState extends State<BankingSetupPage> {
  final Logger _logger = Logger();
  bool _isCheckingSetup = true;
  bool _hasBankingSetup = false;

  @override
  void initState() {
    super.initState();
    _checkBankingSetup();
  }

  Future<void> _checkBankingSetup() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Check if user has a business profile with paystack_subaccount_id
      final businessData = await SupabaseService.instance.client
          .from('trusted_partners')
          .select('paystack_subaccount_id')
          .eq('user_id', user.id)
          .maybeSingle();

      setState(() {
        _hasBankingSetup =
            businessData != null &&
            businessData['paystack_subaccount_id'] != null &&
            businessData['paystack_subaccount_id'].toString().isNotEmpty;
        _isCheckingSetup = false;
      });

      // If banking is already set up, automatically continue to home
      if (_hasBankingSetup) {
        _continueToHome();
      }
    } catch (e) {
      _logger.e('Error checking banking setup: $e');
      setState(() {
        _isCheckingSetup = false;
      });
    }
  }

  Future<void> _openPaystackDashboard() async {
    const paystackUrl =
        'https://dashboard.paystack.com'; // Or specific onboarding URL
    try {
      if (await canLaunchUrl(Uri.parse(paystackUrl))) {
        await launchUrl(Uri.parse(paystackUrl));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to open Paystack dashboard. Please visit https://dashboard.paystack.com manually.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Error opening Paystack dashboard: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Paystack dashboard: $e')),
        );
      }
    }
  }

  Future<void> _continueToHome() async {
    if (!mounted) return;
    await NavigationService().navigateToHomeAfterAuth(context);
  }

  Future<void> _refreshSetupStatus() async {
    setState(() {
      _isCheckingSetup = true;
    });
    await _checkBankingSetup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking Setup'),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.account_balance,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Complete Your Banking Setup',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'To receive payments from members, you need to set up your banking details through Paystack.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.security, size: 40, color: Colors.blue),
                  const SizedBox(height: 12),
                  const Text(
                    'Secure Banking Setup',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your banking details are handled securely by Paystack. We never store or access your banking information.',
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Steps to complete setup:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStep(
                    1,
                    'Click "Set Up Banking" below to open Paystack',
                  ),
                  _buildStep(2, 'Sign in to your Paystack account'),
                  _buildStep(
                    3,
                    'Go to Settings → Banking to add your bank details',
                  ),
                  _buildStep(
                    4,
                    'Return to this app and click "I\'ve Completed Setup"',
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (_isCheckingSetup)
              const CircularProgressIndicator()
            else ...[
              ElevatedButton.icon(
                onPressed: _openPaystackDashboard,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Set Up Banking'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _refreshSetupStatus,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('I\'ve Completed Setup'),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Need help? Contact support@locallekker.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
