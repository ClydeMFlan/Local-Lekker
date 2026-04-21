import 'package:flutter/material.dart';
import '../../services/discount_service.dart';

class OffersPage extends StatefulWidget {
  const OffersPage({super.key});

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  final DiscountService _discountService = DiscountService();
  Map<String, List<Map<String, dynamic>>> _groupedOffers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final offers = await _discountService
          .getAllActiveDiscountsWithTrustedPartners();

      // Group offers by merchant business name
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final offer in offers) {
        final merchant = offer['merchants'] as Map<String, dynamic>?;
        final businessName =
            merchant?['business_name'] as String? ?? 'Unknown Merchant';

        if (!grouped.containsKey(businessName)) {
          grouped[businessName] = [];
        }
        grouped[businessName]!.add(offer);
      }

      setState(() => _groupedOffers = grouped);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load offers: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Offers'),
        actions: [
          IconButton(
            onPressed: _loadOffers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groupedOffers.isEmpty
          ? _buildEmptyState()
          : _buildOffersList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_offer_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No offers available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for new discounts and offers',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadOffers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildOffersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groupedOffers.length,
      itemBuilder: (context, index) {
        final businessName = _groupedOffers.keys.elementAt(index);
        final offers = _groupedOffers[businessName]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                businessName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            ...offers.map(
              (offer) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.local_offer, color: Colors.orange),
                  title: Text(offer['name'] as String),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offer['description'] as String),
                      const SizedBox(height: 4),
                      Text(
                        _getDiscountDisplay(offer),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Offer "${offer['name']}" selected!'),
                        ),
                      );
                    },
                    child: const Text('Claim'),
                  ),
                ),
              ),
            ),
            if (index < _groupedOffers.length - 1) const Divider(),
          ],
        );
      },
    );
  }

  String _getDiscountDisplay(Map<String, dynamic> offer) {
    final percentage = (offer['percentage'] as num).toDouble();
    final fixedAmount = offer['fixed_amount'];

    if (fixedAmount != null && fixedAmount > 0) {
      return 'R${fixedAmount.toStringAsFixed(0)} off';
    } else {
      return '${percentage.toInt()}% off';
    }
  }
}
