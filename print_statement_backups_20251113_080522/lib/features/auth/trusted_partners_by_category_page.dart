import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import 'trusted_partner_shop_page.dart';

class TrustedPartnersByCategoryPage extends StatefulWidget {
  const TrustedPartnersByCategoryPage({super.key});

  @override
  State<TrustedPartnersByCategoryPage> createState() =>
      _TrustedPartnersByCategoryPageState();
}

class _TrustedPartnersByCategoryPageState
    extends State<TrustedPartnersByCategoryPage> {
  final _categories = <String>[];
  String? _selectedCategory;
  List<Map<String, dynamic>> _partners = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      // categories are defined in BusinessProfilePage; here we query distinct business categories
      final res = await SupabaseService.instance.client
          .from('businesses')
          .select('category')
          .order('category', ascending: true);

      final cats = <String>{};
      for (final r in res) {
        final c = (r['category'] as String?)?.trim();
        if (c != null && c.isNotEmpty) cats.add(c);
      }

      setState(() {
        _categories.clear();
        _categories.addAll(cats.toList()..sort());
        if (_categories.isNotEmpty) _selectedCategory = _categories.first;
      });

      if (_selectedCategory != null) {
        await _loadPartnersForCategory(_selectedCategory!);
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load categories: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadPartnersForCategory(String category) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final businesses = await SupabaseService.instance.client
          .from('businesses')
          .select('id, owner_member_id, name, category, address')
          .eq('category', category)
          .order('name', ascending: true);

      final partners = <Map<String, dynamic>>[];
      for (final b in businesses) {
        // Get profile data including address components
        final profile = await SupabaseService.instance.client
            .from('profiles')
            .select('name, surname, street, suburb, city, province')
            .eq('id', b['owner_member_id'])
            .maybeSingle();
        final ownerName = profile != null
            ? '${profile['name']} ${profile['surname']}'
            : 'Business Owner';

        // Build address from components
        final addressParts = <String>[];
        if (profile != null) {
          if (profile['street'] != null &&
              profile['street'].toString().isNotEmpty) {
            addressParts.add(profile['street']);
          }
          if (profile['suburb'] != null &&
              profile['suburb'].toString().isNotEmpty) {
            addressParts.add(profile['suburb']);
          }
          if (profile['city'] != null &&
              profile['city'].toString().isNotEmpty) {
            addressParts.add(profile['city']);
          }
        }
        final address = addressParts.isNotEmpty
            ? addressParts.join(', ')
            : 'No address available';

        // Get count of active deals for this partner
        // Query by trusted_partner_id (which is the owner_member_id)
        final dealData = await SupabaseService.instance.client
            .from('trusted_partner_discounts')
            .select('id')
            .eq('trusted_partner_id', b['owner_member_id'])
            .eq('is_active', true);

        print(
          'Partner ${b['name']} (owner: ${b['owner_member_id']}): Found ${(dealData as List).length} deals',
        );

        partners.add({
          ...b,
          'owner_name': ownerName,
          'address': address,
          'deal_count': (dealData as List).length,
        });
      }

      setState(() {
        _partners = partners;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load partners: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Partners'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadCategories();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadCategories,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a category',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() {
                        _selectedCategory = v;
                      });
                      await _loadPartnersForCategory(v);
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _partners.isEmpty
                        ? const Center(
                            child: Text('No partners found in this category'),
                          )
                        : ListView.builder(
                            itemCount: _partners.length,
                            itemBuilder: (context, index) {
                              final p = _partners[index];
                              final dealCount = p['deal_count'] ?? 0;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  title: Text(
                                    p['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        p['address'] ?? 'No address available',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '$dealCount ${dealCount == 1 ? 'deal' : 'deals'} available',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            TrustedPartnerShopPage(partner: p),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
