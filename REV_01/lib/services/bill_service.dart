import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import '../services/receipt_parser_service.dart';

class ProcessedBill {
  final String id;
  final String memberId;
  final String discountId;
  final String partnerId;
  final ReceiptData receiptData;
  final double originalTotal;
  final double discountAmount;
  final double discountedTotal;
  final DateTime processedAt;
  final String? imageUrl;

  ProcessedBill({
    required this.id,
    required this.memberId,
    required this.discountId,
    required this.partnerId,
    required this.receiptData,
    required this.originalTotal,
    required this.discountAmount,
    required this.discountedTotal,
    required this.processedAt,
    this.imageUrl,
  });

  factory ProcessedBill.fromMap(Map<String, dynamic> map) {
    return ProcessedBill(
      id: map['id'],
      memberId: map['member_id'],
      discountId: map['discount_id'],
      partnerId: map['partner_id'],
      receiptData: ReceiptData(
        items: (map['receipt_data']['items'] as List)
            .map(
              (item) => ReceiptItem(
                name: item['name'],
                price: item['price'],
                quantity: item['quantity'],
                isDiscountItem: item['isDiscountItem'] ?? false,
              ),
            )
            .toList(),
        subtotal: map['receipt_data']['subtotal'],
        tax: map['receipt_data']['tax'],
        total: map['receipt_data']['total'],
        merchantName: map['receipt_data']['merchantName'],
        date: map['receipt_data']['date'] != null
            ? DateTime.parse(map['receipt_data']['date'])
            : null,
      ),
      originalTotal: map['original_total'],
      discountAmount: map['discount_amount'],
      discountedTotal: map['discounted_total'],
      processedAt: DateTime.parse(map['processed_at']),
      imageUrl: map['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'member_id': memberId,
      'discount_id': discountId,
      'partner_id': partnerId,
      'receipt_data': {
        'items': receiptData.items.map((item) => item.toMap()).toList(),
        'subtotal': receiptData.subtotal,
        'tax': receiptData.tax,
        'total': receiptData.total,
        'merchantName': receiptData.merchantName,
        'date': receiptData.date?.toIso8601String(),
      },
      'original_total': originalTotal,
      'discount_amount': discountAmount,
      'discounted_total': discountedTotal,
      'processed_at': processedAt.toIso8601String(),
      'image_url': imageUrl,
    };
  }
}

class BillService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Logger _logger = Logger();

  /// Upload receipt image to Supabase storage
  Future<String?> uploadReceiptImage(
    String memberId,
    List<int> imageBytes,
    String fileName,
  ) async {
    try {
      final filePath =
          'receipts/$memberId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await _supabase.storage
          .from('receipt-images')
          .uploadBinary(filePath, Uint8List.fromList(imageBytes));

      // Get public URL
      final imageUrl = _supabase.storage
          .from('receipt-images')
          .getPublicUrl(filePath);

      return imageUrl;
    } catch (e) {
      _logger.e('Failed to upload receipt image: $e');
      return null;
    }
  }

  Future<ProcessedBill> saveProcessedBill({
    required String memberId,
    required String discountId,
    required String partnerId,
    required ReceiptData receiptData,
    required double originalTotal,
    required double discountAmount,
    required double discountedTotal,
    String? imageUrl,
  }) async {
    try {
      final billData = {
        'member_id': memberId,
        'discount_id': discountId,
        'partner_id': partnerId,
        'receipt_data': {
          'items': receiptData.items.map((item) => item.toMap()).toList(),
          'subtotal': receiptData.subtotal,
          'tax': receiptData.tax,
          'total': receiptData.total,
          'merchantName': receiptData.merchantName,
          'date': receiptData.date?.toIso8601String(),
        },
        'original_total': originalTotal,
        'discount_amount': discountAmount,
        'discounted_total': discountedTotal,
        'image_url': imageUrl,
      };

      final response = await _supabase
          .from('processed_bills')
          .insert(billData)
          .select()
          .single();

      return ProcessedBill.fromMap(response);
    } catch (e) {
      throw Exception('Failed to save processed bill: $e');
    }
  }

  Future<List<ProcessedBill>> getMemberProcessedBills(String memberId) async {
    try {
      final response = await _supabase
          .from('processed_bills')
          .select('*')
          .eq('member_id', memberId)
          .order('processed_at', ascending: false);

      return (response as List)
          .map((bill) => ProcessedBill.fromMap(bill))
          .toList();
    } catch (e) {
      throw Exception('Failed to get processed bills: $e');
    }
  }

  Future<ProcessedBill?> getBillById(String billId) async {
    try {
      final response = await _supabase
          .from('processed_bills')
          .select('*')
          .eq('id', billId)
          .single();

      return ProcessedBill.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  Future<bool> hasMemberUsedDiscount(String memberId, String discountId) async {
    try {
      final response = await _supabase
          .from('processed_bills')
          .select('id')
          .eq('member_id', memberId)
          .eq('discount_id', discountId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> getMemberBillStats(String memberId) async {
    try {
      final response = await _supabase
          .from('processed_bills')
          .select('original_total, discount_amount, discounted_total')
          .eq('member_id', memberId);

      double totalSaved = 0.0;
      double totalSpent = 0.0;
      int billsProcessed = response.length;

      for (var bill in response) {
        totalSaved += bill['discount_amount'] as double;
        totalSpent += bill['original_total'] as double;
      }

      return {
        'totalSaved': totalSaved,
        'totalSpent': totalSpent,
        'billsProcessed': billsProcessed,
        'averageSaving': billsProcessed > 0 ? totalSaved / billsProcessed : 0.0,
      };
    } catch (e) {
      return {
        'totalSaved': 0.0,
        'totalSpent': 0.0,
        'billsProcessed': 0,
        'averageSaving': 0.0,
      };
    }
  }
}
