import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../models/profile.dart';
import 'admin_trusted_partner_profile_page.dart';

class TrustedPartnersListScreen extends StatefulWidget {
  const TrustedPartnersListScreen({super.key});

  @override
  State<TrustedPartnersListScreen> createState() =>
      _TrustedPartnersListScreenState();
}

class _TrustedPartnersListScreenState extends State<TrustedPartnersListScreen> {
  List<Profile> trustedPartners = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadTrustedPartners();
  }

  Future<void> _loadTrustedPartners() async {
    try {
      print('🔍 Loading trusted partners...');

      // Query profiles directly with role='trusted_partner'
      // This bypasses any membership RLS issues
      final data = await SupabaseService.instance.client
          .from('profiles')
          .select('*')
          .eq('role', 'trusted_partner')
          .order('created_at', ascending: true);

      print('✅ Loaded ${data.length} trusted partner profiles');

      if (data.isEmpty) {
        print('⚠️ No profiles found with role=trusted_partner');
      } else {
        print('🔍 Partner details:');
        for (var profile in data) {
          print(
            '  - ${profile['name']} ${profile['surname']} (${profile['email']})',
          );
        }
      }

      setState(() {
        trustedPartners = data.map((json) => Profile.fromJson(json)).toList();
        loading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error loading trusted partners: $e');
      print('Stack trace: $stackTrace');
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load trusted partners: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _deleteTrustedPartner(String userId) async {
    try {
      await SupabaseService.instance.client
          .from('profiles')
          .delete()
          .eq('id', userId);

      await SupabaseService.instance.client
          .from('memberships')
          .delete()
          .eq('user_id', userId);

      setState(() {
        trustedPartners.removeWhere((partner) => partner.id == userId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trusted partner deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete trusted partner: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Partners'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : trustedPartners.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Trusted Partners Yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add trusted partners from the admin dashboard',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadTrustedPartners,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTrustedPartners,
              child: ListView.builder(
                itemCount: trustedPartners.length,
                itemBuilder: (context, index) {
                  final partner = trustedPartners[index];
                  return ListTile(
                    title: Text(
                      '${partner.name ?? ''} ${partner.surname ?? ''}',
                    ),
                    subtitle: Text(partner.email ?? 'No email'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _showDeleteConfirmation(partner),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AdminTrustedPartnerProfilePage(partner: partner),
                        ),
                      ).then((_) {
                        // Reload list when returning from profile page
                        _loadTrustedPartners();
                      });
                    },
                  );
                },
              ),
            ),
    );
  }

  void _showDeleteConfirmation(Profile partner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trusted Partner'),
        content: Text(
          'Are you sure you want to delete ${partner.name} ${partner.surname}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTrustedPartner(partner.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
