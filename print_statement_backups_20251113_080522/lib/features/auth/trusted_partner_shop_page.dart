import 'package:flutter/material.dart';
import '../../models/discount.dart';
import '../../services/discount_service.dart';
import '../../services/supabase_service.dart';
import 'deal_selection_page.dart'; // Import for BillDiscountDialog

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

      print('🔍 Loading discounts for partner: ${widget.partner['name']}');
      print('🔍 Owner member ID: ${widget.partner['owner_member_id']}');

      final ownerMemberId = widget.partner['owner_member_id'];
      if (ownerMemberId == null || ownerMemberId.toString().isEmpty) {
        throw Exception(
          'No owner_member_id found for partner "${widget.partner['name']}"',
        );
      }

      // Use the same method as browse deals page - this is known to work
      await _discountService.fixDiscountVisibility();

      final allDeals = await _discountService
          .getAllActiveDiscountsWithTrustedPartners();

      print('🔍 Total active deals across all partners: ${allDeals.length}');

      // Filter for this specific partner
      final partnerDeals = allDeals.where((deal) {
        // Match by owner_member_id (trusted_partner_id)
        return deal['trusted_partner_id'] == ownerMemberId;
      }).toList();

      print(
        '📊 Found ${partnerDeals.length} active deals for ${widget.partner['name']}',
      );

      if (partnerDeals.isNotEmpty) {
        print('🔍 First deal data: ${partnerDeals.first}');
      }

      // Convert to Discount objects
      final discounts = partnerDeals
          .map((deal) => Discount.fromJson(deal))
          .toList();

      print('✅ Converted to ${discounts.length} Discount objects');
      if (discounts.isNotEmpty) {
        print(
          '✅ First discount: ${discounts.first.name} - ${discounts.first.description}',
        );
      }

      if (mounted) {
        setState(() {
          _discounts = discounts;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error loading discounts: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Failed to load discounts: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _showBillDiscountDialog(BuildContext context, Discount discount) {
    // Create a deal map similar to what browse deals page uses
    final deal = discount.toJson();
    deal['trusted_partners'] = {
      'business_name': widget.partner['name'],
      'business_id': widget.partner['id'] ?? widget.partner['business_id'],
    };

    showDialog(
      context: context,
      builder: (context) => BillDiscountDialog(
        discount: discount,
        trustedPartnerName: widget.partner['name'] ?? 'Unknown Partner',
        deal: deal,
      ),
    );
  }

  void _showItemDealDialog(BuildContext context, Discount discount) {
    int quantity = discount.isWeightBased ? 100 : 1; // Default quantity
    double totalPrice = discount.isWeightBased
        ? (discount.dealPrice * quantity) / 1000
        : discount.dealPrice * quantity;
    double totalSavings = discount.isWeightBased
        ? (discount.savings * quantity) / 1000
        : discount.savings * quantity;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(discount.name),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Partner info
                Text(
                  widget.partner['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),

                // Item details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.shopping_bag,
                            size: 20,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              discount.itemName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            discount.isWeightBased
                                ? 'R${discount.itemPrice.toStringAsFixed(2)}/kg'
                                : 'R${discount.itemPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            discount.isWeightBased
                                ? 'R${discount.dealPrice.toStringAsFixed(2)}/kg'
                                : 'R${discount.dealPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          discount.isWeightBased
                              ? 'Save R${discount.savings.toStringAsFixed(2)}/kg'
                              : 'Save R${discount.savings.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quantity selector
                Row(
                  children: [
                    const Text(
                      'Qty:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (discount.isWeightBased) {
                                  if (quantity > 100) {
                                    quantity -= 100;
                                    totalPrice =
                                        (discount.dealPrice * quantity) / 1000;
                                    totalSavings =
                                        (discount.savings * quantity) / 1000;
                                  }
                                } else {
                                  if (quantity > 1) {
                                    quantity -= 1;
                                    totalPrice = discount.dealPrice * quantity;
                                    totalSavings = discount.savings * quantity;
                                  }
                                }
                              });
                            },
                            icon: const Icon(Icons.remove, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                          Container(
                            width: discount.isWeightBased ? 55 : 30,
                            alignment: Alignment.center,
                            child: Text(
                              discount.isWeightBased
                                  ? '${quantity}g'
                                  : quantity.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                if (discount.isWeightBased) {
                                  quantity += 100;
                                  totalPrice =
                                      (discount.dealPrice * quantity) / 1000;
                                  totalSavings =
                                      (discount.savings * quantity) / 1000;
                                } else {
                                  quantity += 1;
                                  totalPrice = discount.dealPrice * quantity;
                                  totalSavings = discount.savings * quantity;
                                }
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Total display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total: R${totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            'You save: R${totalSavings.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          discount.isWeightBased
                              ? '${quantity}g'
                              : '${quantity}x',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  // Create deal authorization request
                  final currentUser =
                      SupabaseService.instance.client.auth.currentUser;
                  if (currentUser == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('User not authenticated')),
                      );
                    }
                    return;
                  }

                  final businessId =
                      widget.partner['business_id'] ??
                      widget.partner['owner_member_id'];

                  await SupabaseService.instance.client
                      .from('deal_authorizations')
                      .insert({
                        'member_id': currentUser.id,
                        'business_id': businessId,
                        'discount_id': discount.id,
                        'status': 'pending',
                        'amount': totalPrice,
                        'notes':
                            'Item deal request: ${discount.itemName} x$quantity',
                        'created_at': DateTime.now().toIso8601String(),
                      });

                  if (mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deal authorization request submitted'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to submit request: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Request Deal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print(
      '🎨 Building UI - isLoading: $_isLoading, error: $_error, discounts: ${_discounts.length}',
    );

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
                        discount.isBillDiscount
                            ? Icons.receipt_long
                            : Icons.shopping_bag,
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
                        Text(
                          discount.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
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
                            if (discount.isBillDiscount)
                              Text(
                                discount.percentage > 0
                                    ? '${discount.percentage.toStringAsFixed(0)}% off bill'
                                    : 'R${discount.fixedAmount?.toStringAsFixed(2)} off bill',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              )
                            else ...[
                              Text(
                                discount.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                discount.isWeightBased
                                    ? 'R${discount.dealPrice.toStringAsFixed(2)}/kg'
                                    : 'R${discount.dealPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
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
                      // Show popup with browse deals logic instead of scan receipt
                      if (discount.isActive) {
                        if (discount.isBillDiscount) {
                          // Show bill discount request dialog
                          _showBillDiscountDialog(context, discount);
                        } else {
                          // Show item-based deal selection dialog
                          _showItemDealDialog(context, discount);
                        }
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
