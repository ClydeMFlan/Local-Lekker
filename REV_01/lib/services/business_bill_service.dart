import 'dart:typed_data';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class BusinessBill {
  final String id;
  final String businessId;
  final String billUrl;
  final String businessName;
  final DateTime uploadedAt;
  final bool isActive;
  final List<String>? extractedFeatures; // OCR and layout features

  BusinessBill({
    required this.id,
    required this.businessId,
    required this.billUrl,
    required this.businessName,
    required this.uploadedAt,
    this.isActive = true,
    this.extractedFeatures,
  });

  factory BusinessBill.fromMap(Map<String, dynamic> map) {
    return BusinessBill(
      id: map['id'],
      businessId: map['business_id'],
      billUrl: map['bill_url'],
      businessName: map['business_name'],
      uploadedAt: DateTime.parse(map['uploaded_at']),
      isActive: map['is_active'] ?? true,
      extractedFeatures: map['extracted_features'] != null
          ? List<String>.from(map['extracted_features'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'bill_url': billUrl,
      'business_name': businessName,
      'uploaded_at': uploadedAt.toIso8601String(),
      'is_active': isActive,
      'extracted_features': extractedFeatures,
    };
  }
}

class BusinessBillService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final ImageLabeler _imageLabeler;
  late final TextRecognizer _textRecognizer;

  BusinessBillService() {
    _imageLabeler = ImageLabeler(options: ImageLabelerOptions());
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Upload a business bill to Supabase storage and create database record
  Future<BusinessBill> uploadBusinessBill({
    required String businessId,
    required String businessName,
    required List<int> billBytes,
    required String fileName,
  }) async {
    try {
      // Extract features from the bill for OCR calibration
      final extractedFeatures = await _extractBillFeatures(billBytes);

      // Upload bill to storage
      final filePath =
          'business-bills/$businessId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _supabase.storage
          .from('business-bills')
          .uploadBinary(filePath, Uint8List.fromList(billBytes));

      // Get public URL
      final billUrl = _supabase.storage
          .from('business-bills')
          .getPublicUrl(filePath);

      // Create database record
      final billData = {
        'business_id': businessId,
        'bill_url': billUrl,
        'business_name': businessName,
        'is_active': true,
        'extracted_features': extractedFeatures,
      };

      final response = await _supabase
          .from('business_bills')
          .insert(billData)
          .select()
          .single();

      return BusinessBill.fromMap(response);
    } catch (e) {
      throw Exception('Failed to upload business bill: $e');
    }
  }

  /// Extract bill features for recognition (using Google ML Kit Image Labeling and Text Recognition)
  Future<List<String>> _extractBillFeatures(List<int> billBytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: Uint8List.fromList(billBytes),
        metadata: InputImageMetadata(
          size: const Size(300, 400),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: 0,
        ),
      );

      // Extract image labels (for logos, layout elements, etc.)
      final labels = await _imageLabeler.processImage(inputImage);
      final imageLabels = labels
          .map((label) => 'label:${label.label}')
          .toList();

      // Extract text from bill
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final textElements = <String>[];

      // Extract text blocks and lines for layout understanding
      for (final block in recognizedText.blocks) {
        textElements.add('block:${block.text}');
        for (final line in block.lines) {
          textElements.add('line:${line.text}');
        }
      }

      // Combine features
      return [...imageLabels, ...textElements];
    } catch (e) {
      // Fallback to basic image labeling if text recognition fails
      return await _extractLogoFeatures(billBytes);
    }
  }

  /// Extract logo features for recognition (using Google ML Kit Image Labeling)
  Future<List<String>> _extractLogoFeatures(List<int> logoBytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: Uint8List.fromList(logoBytes),
        metadata: InputImageMetadata(
          size: const Size(300, 400),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: 0,
        ),
      );

      final labels = await _imageLabeler.processImage(inputImage);
      return labels.map((label) => label.label).toList();
    } catch (e) {
      // Fallback to empty list if image labeling fails
      return [];
    }
  }

  /// Get all active business bills for OCR calibration
  Future<List<BusinessBill>> getActiveBusinessBills() async {
    try {
      final response = await _supabase
          .from('business_bills')
          .select()
          .eq('is_active', true)
          .order('uploaded_at', ascending: false);

      return (response as List)
          .map((bill) => BusinessBill.fromMap(bill))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get bills for a specific business
  Future<List<BusinessBill>> getBusinessBills(String businessId) async {
    try {
      final response = await _supabase
          .from('business_bills')
          .select()
          .eq('business_id', businessId)
          .order('uploaded_at', ascending: false);

      return (response as List)
          .map((bill) => BusinessBill.fromMap(bill))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Deactivate a business logo
  Future<void> deactivateLogo(String logoId) async {
    try {
      await _supabase
          .from('business_logos')
          .update({'is_active': false})
          .eq('id', logoId);
    } catch (e) {
      throw Exception('Failed to deactivate logo: $e');
    }
  }

  /// Match a receipt image against known business bills for automatic recognition
  Future<String?> matchBillInReceipt(List<int> receiptBytes) async {
    try {
      // This implementation analyzes receipt features against stored bill templates
      // to automatically identify which business the receipt belongs to

      final bills = await getActiveBusinessBills();
      if (bills.isEmpty) return null;

      // Extract features from the new receipt
      final receiptFeatures = await _extractBillFeatures(receiptBytes);

      // Compare features with stored bill templates
      // This is a simplified implementation - in production, you might use:
      // - Cosine similarity on feature vectors
      // - Machine learning models trained on bill layouts
      // - Template matching algorithms

      for (final bill in bills) {
        if (bill.extractedFeatures != null &&
            bill.extractedFeatures!.isNotEmpty) {
          // Simple feature overlap check
          final overlap = receiptFeatures
              .where(
                (feature) => bill.extractedFeatures!.any(
                  (billFeature) =>
                      feature.contains(billFeature) ||
                      billFeature.contains(feature),
                ),
              )
              .length;

          // If significant overlap, consider it a match
          if (overlap > receiptFeatures.length * 0.3) {
            // 30% feature overlap threshold
            return bill.businessName;
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Deactivate a business bill
  Future<void> deactivateBill(String billId) async {
    try {
      await _supabase
          .from('business_bills')
          .update({'is_active': false})
          .eq('id', billId);
    } catch (e) {
      throw Exception('Failed to deactivate bill: $e');
    }
  }

  void dispose() {
    _imageLabeler.close();
    _textRecognizer.close();
  }
}
