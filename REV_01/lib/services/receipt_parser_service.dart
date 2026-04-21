import 'dart:typed_data';
import 'dart:ui';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

enum ReceiptTemplate { generic, thermal, woolworths, pickNPay, spar, checkers }

class ReceiptItem {
  final String name;
  final double price;
  final int quantity;
  final bool isDiscountItem;

  ReceiptItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.isDiscountItem = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'isDiscountItem': isDiscountItem,
    };
  }
}

class ReceiptData {
  final List<ReceiptItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String merchantName;
  final DateTime? date;

  ReceiptData({
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.merchantName,
    this.date,
  });
}

class ReceiptParserService {
  late final TextRecognizer _textRecognizer;

  ReceiptParserService() {
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  }

  Future<ReceiptData> parseReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return _parseTextToReceipt(recognizedText);
    } catch (e) {
      throw Exception('Failed to process receipt: $e');
    }
  }

  Future<ReceiptData> parseReceiptFromBytes(List<int> imageBytes) async {
    try {
      final inputImage = InputImage.fromBytes(
        bytes: Uint8List.fromList(imageBytes),
        metadata: InputImageMetadata(
          size: const Size(300, 400),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.yuv420,
          bytesPerRow: 0,
        ),
      );
      final recognizedText = await _textRecognizer.processImage(inputImage);

      return _parseTextToReceipt(recognizedText);
    } catch (e) {
      throw Exception('Failed to process receipt: $e');
    }
  }

  ReceiptData _parseTextToReceipt(RecognizedText recognizedText) {
    final lines = recognizedText.blocks
        .expand((block) => block.lines)
        .map((line) => line.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    // Detect receipt template type
    final templateType = _detectReceiptTemplate(lines);

    // Extract merchant name (usually first line or prominent text)
    String merchantName = _extractMerchantName(lines, templateType);

    // Extract date
    DateTime? date = _extractDate(lines, templateType);

    // Parse items, prices, and quantities based on template
    List<ReceiptItem> items = _parseItemsByTemplate(lines, templateType);

    // Calculate totals
    double subtotal = items.fold(
      0.0,
      (sum, item) => sum + (item.price * item.quantity),
    );
    double tax = _extractTax(lines, subtotal, templateType);
    double total = _extractTotal(lines, templateType);

    // If total is not found, use calculated total
    if (total == 0.0) {
      total = subtotal + tax;
    }

    return ReceiptData(
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      merchantName: merchantName,
      date: date,
    );
  }

  ReceiptTemplate _detectReceiptTemplate(List<String> lines) {
    // Check for common receipt patterns
    final text = lines.join(' ').toLowerCase();

    // Woolworths pattern
    if (text.contains('woolworths') || text.contains('woolies')) {
      return ReceiptTemplate.woolworths;
    }

    // Pick n Pay pattern
    if (text.contains('pick n pay') || text.contains('pnp')) {
      return ReceiptTemplate.pickNPay;
    }

    // Spar pattern
    if (text.contains('spar')) {
      return ReceiptTemplate.spar;
    }

    // Check n Go pattern
    if (text.contains('checkers') || text.contains('check n go')) {
      return ReceiptTemplate.checkers;
    }

    // Generic thermal receipt pattern (most common)
    if (_hasThermalReceiptPattern(lines)) {
      return ReceiptTemplate.thermal;
    }

    return ReceiptTemplate.generic;
  }

  bool _hasThermalReceiptPattern(List<String> lines) {
    // Thermal receipts typically have:
    // - Short lines (40-48 characters)
    // - Prices aligned to the right
    // - Item descriptions followed by prices
    int shortLines = 0;
    int priceLines = 0;

    for (String line in lines) {
      if (line.length <= 48) shortLines++;
      if (_isPrice(line) || line.contains('.')) priceLines++;
    }

    return shortLines > lines.length * 0.6 && priceLines > lines.length * 0.3;
  }

  String _extractMerchantName(List<String> lines, ReceiptTemplate template) {
    if (lines.isEmpty) return 'Unknown Merchant';

    // Template-specific merchant name extraction
    switch (template) {
      case ReceiptTemplate.woolworths:
        return _extractWoolworthsMerchant(lines);
      case ReceiptTemplate.pickNPay:
        return _extractPickNPayMerchant(lines);
      case ReceiptTemplate.spar:
        return _extractSparMerchant(lines);
      case ReceiptTemplate.checkers:
        return _extractCheckersMerchant(lines);
      default:
        return _extractGenericMerchant(lines);
    }
  }

  String _extractGenericMerchant(List<String> lines) {
    // Look for common merchant patterns
    for (String line in lines) {
      // Skip lines that look like addresses, phone numbers, or prices
      if (_isAddress(line) || _isPhoneNumber(line) || _isPrice(line)) {
        continue;
      }

      // Look for lines that might be merchant names (not too long, not prices)
      if (line.length > 3 && line.length < 50 && !_containsNumbers(line)) {
        return line;
      }
    }

    return lines.first; // Fallback to first line
  }

  String _extractWoolworthsMerchant(List<String> lines) {
    for (String line in lines) {
      if (line.toLowerCase().contains('woolworths')) {
        return 'Woolworths';
      }
    }
    return 'Woolworths';
  }

  String _extractPickNPayMerchant(List<String> lines) {
    for (String line in lines) {
      if (line.toLowerCase().contains('pick n pay') ||
          line.toLowerCase().contains('pnp')) {
        return 'Pick n Pay';
      }
    }
    return 'Pick n Pay';
  }

  String _extractSparMerchant(List<String> lines) {
    for (String line in lines) {
      if (line.toLowerCase().contains('spar')) {
        return 'Spar';
      }
    }
    return 'Spar';
  }

  String _extractCheckersMerchant(List<String> lines) {
    for (String line in lines) {
      if (line.toLowerCase().contains('checkers') ||
          line.toLowerCase().contains('check n go')) {
        return 'Checkers';
      }
    }
    return 'Checkers';
  }

  DateTime? _extractDate(List<String> lines, ReceiptTemplate template) {
    final dateRegex = RegExp(
      r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{2,4}[/-]\d{1,2}[/-]\d{1,2})',
    );

    for (String line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        try {
          return DateTime.parse(match.group(0)!);
        } catch (e) {
          // Try different date formats based on template
          switch (template) {
            case ReceiptTemplate.woolworths:
              return _parseWoolworthsDate(line);
            case ReceiptTemplate.pickNPay:
              return _parsePickNPayDate(line);
            default:
              continue;
          }
        }
      }
    }
    return null;
  }

  DateTime? _parseWoolworthsDate(String line) {
    // Woolworths format: DD/MM/YYYY or DD/MM/YY
    final regex = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})');
    final match = regex.firstMatch(line);
    if (match != null) {
      final day = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final year = int.parse(match.group(3)!);
      final fullYear = year < 100 ? 2000 + year : year;
      return DateTime(fullYear, month, day);
    }
    return null;
  }

  DateTime? _parsePickNPayDate(String line) {
    // Pick n Pay format: YYYY-MM-DD or similar
    final regex = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})');
    final match = regex.firstMatch(line);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }
    return null;
  }

  List<ReceiptItem> _parseItemsByTemplate(
    List<String> lines,
    ReceiptTemplate template,
  ) {
    switch (template) {
      case ReceiptTemplate.thermal:
        return _parseThermalItems(lines);
      case ReceiptTemplate.woolworths:
        return _parseWoolworthsItems(lines);
      case ReceiptTemplate.pickNPay:
        return _parsePickNPayItems(lines);
      default:
        return _parseGenericItems(lines);
    }
  }

  List<ReceiptItem> _parseGenericItems(List<String> lines) {
    List<ReceiptItem> items = [];
    final priceRegex = RegExp(r'(\d+\.?\d{0,2})');
    final quantityRegex = RegExp(r'^(\d+)\s*x?\s*');

    for (String line in lines) {
      // Skip lines that are clearly not items
      if (_isAddress(line) ||
          _isPhoneNumber(line) ||
          _isTotal(line) ||
          _isTax(line)) {
        continue;
      }

      // Look for lines with prices
      final priceMatches = priceRegex.allMatches(line).toList();
      if (priceMatches.isNotEmpty) {
        final lastPriceMatch = priceMatches.last;
        final price = double.tryParse(lastPriceMatch.group(0)!) ?? 0.0;

        if (price > 0) {
          // Extract item name (everything before the price)
          final priceStart = lastPriceMatch.start;
          String itemName = line.substring(0, priceStart).trim();

          // Check for quantity
          int quantity = 1;
          final quantityMatch = quantityRegex.firstMatch(itemName);
          if (quantityMatch != null) {
            quantity = int.tryParse(quantityMatch.group(1)!) ?? 1;
            itemName = itemName.replaceFirst(quantityRegex, '').trim();
          }

          // Clean up item name
          itemName = itemName.replaceAll(RegExp(r'[^\w\s]'), '').trim();
          if (itemName.isNotEmpty) {
            items.add(
              ReceiptItem(name: itemName, price: price, quantity: quantity),
            );
          }
        }
      }
    }

    return items;
  }

  List<ReceiptItem> _parseThermalItems(List<String> lines) {
    // Thermal receipts have items with prices aligned to the right
    return _parseGenericItems(lines);
  }

  List<ReceiptItem> _parseWoolworthsItems(List<String> lines) {
    // Woolworths specific parsing logic
    return _parseGenericItems(lines);
  }

  List<ReceiptItem> _parsePickNPayItems(List<String> lines) {
    // Pick n Pay specific parsing logic
    return _parseGenericItems(lines);
  }

  double _extractTax(
    List<String> lines,
    double subtotal,
    ReceiptTemplate template,
  ) {
    final taxRegex = RegExp(
      r'(?:tax|vat|gst)\s*:?\s*(\d+\.?\d{0,2})',
      caseSensitive: false,
    );

    for (String line in lines) {
      final match = taxRegex.firstMatch(line);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0.0;
      }

      // Also check for percentage-based tax
      final percentRegex = RegExp(
        r'(\d+\.?\d{0,2})%\s*(?:tax|vat|gst)',
        caseSensitive: false,
      );
      final percentMatch = percentRegex.firstMatch(line);
      if (percentMatch != null) {
        final percentage = double.tryParse(percentMatch.group(1)!) ?? 0.0;
        return subtotal * (percentage / 100.0);
      }
    }

    return 0.0;
  }

  double _extractTotal(List<String> lines, ReceiptTemplate template) {
    final totalRegex = RegExp(
      r'(?:total|amount|sum)\s*:?\s*(\d+\.?\d{0,2})',
      caseSensitive: false,
    );

    for (String line in lines) {
      final match = totalRegex.firstMatch(line);
      if (match != null) {
        return double.tryParse(match.group(1)!) ?? 0.0;
      }
    }

    return 0.0;
  }

  bool _isAddress(String line) {
    // Simple heuristics for address detection
    return line.contains('@') || // email
        line.contains('www.') || // website
        (line.split(' ').length > 3 &&
            !line.contains(
              RegExp(r'\d+\.?\d{0,2}'),
            )); // long line without price
  }

  bool _isPhoneNumber(String line) {
    return RegExp(r'\d{3,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4}').hasMatch(line);
  }

  bool _isPrice(String line) {
    return RegExp(r'^\s*\d+\.?\d{0,2}\s*$').hasMatch(line);
  }

  bool _isTotal(String line) {
    return RegExp(
      r'(total|subtotal|sum|amount)',
      caseSensitive: false,
    ).hasMatch(line);
  }

  bool _isTax(String line) {
    return RegExp(r'(tax|vat|gst)', caseSensitive: false).hasMatch(line);
  }

  bool _containsNumbers(String line) {
    return RegExp(r'\d').hasMatch(line);
  }

  void dispose() {
    _textRecognizer.close();
  }
}
