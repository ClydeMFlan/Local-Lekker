import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/discount.dart';
import '../../services/discount_service.dart';
import 'bill_scanner_dialog.dart';

class TrustedPartnerShopPage extends StatefulWidget {
  final Map<String, dynamic> partner;

  const TrustedPartnerShopPage({super.key, required this.partner});

  @override
  State<TrustedPartnerShopPage> createState() => _TrustedPartnerShopPageState();
}

class _TrustedPartnerShopPageState extends State<TrustedPartnerShopPage> {
  final DiscountService _discountService = DiscountService();
  List<Discount> _discounts = [];
  bool _isLoading = true;
  String? _error;
  final Logger _logger = Logger();

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  Future<void> _loadDiscounts() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _logger.i('Loading discounts for partner: ${widget.partner['name']}');

      // Get all discounts created by this trusted partner
      final discounts = await _discountService.getAllTrustedPartnerDiscounts(
        widget.partner['owner_member_id'],
      );

      _logger.i(
        'Found ${discounts.length} discounts for ${widget.partner['name']}',
      );

      setState(() {
        _discounts = discounts;
        _isLoading = false;
      });
    } catch (e) {
      _logger.e('Error loading discounts: $e');
      setState(() {
        _error = 'Failed to load discounts: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.partner['name']} Shop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiscounts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDiscounts,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _discounts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No discounts available',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.partner['name']} hasn\'t added any discounts yet',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _discounts.length,
              itemBuilder: (context, index) {
                final discount = _discounts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: discount.isActive
                          ? Colors.green.shade100
                          : Colors.grey.shade100,
                      child: Icon(
                        Icons.local_offer,
                        color: discount.isActive
                            ? Colors.green.shade700
                            : Colors.grey.shade700,
                      ),
                    ),
                    title: Text(
                      discount.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: discount.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(discount.description),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: discount.isActive
                                    ? Colors.green.shade100
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                discount.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: discount.isActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${discount.percentage.toStringAsFixed(0)}% off',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            if (discount.fixedAmount != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'or R${discount.fixedAmount!.toStringAsFixed(2)} off',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    trailing: discount.isActive
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.cancel, color: Colors.grey),
                    onTap: () {
                      // Always open scan screen directly for active discounts,
                      // regardless of whether there are single or multiple discounts
                      if (discount.isActive) {
                        showDialog(
                          context: context,
                          builder: (context) => BillScannerDialog(
                            discount: discount,
                            partner: widget.partner,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'This discount is currently inactive',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
