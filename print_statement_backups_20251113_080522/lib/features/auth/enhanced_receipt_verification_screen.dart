import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../../services/receipt_parser_service.dart' as receipt_parser;
import '../../models/discount.dart';

class EnhancedReceiptVerificationScreen extends StatefulWidget {
  final List<receipt_parser.TextBlockData> extractedTextBlocks;
  final List<int> imageBytes;
  final receipt_parser.ReceiptParserService receiptParser;
  final String? identifiedBusinessName;
  final List<Discount> availableDiscounts;
  final Map<String, List<String>>
  discountMatches; // item name -> discount names
  final List<Map<String, dynamic>>? availableTrustedPartners;

  const EnhancedReceiptVerificationScreen({
    super.key,
    required this.extractedTextBlocks,
    required this.imageBytes,
    required this.receiptParser,
    this.identifiedBusinessName,
    this.availableDiscounts = const [],
    this.discountMatches = const {},
    this.availableTrustedPartners,
  });

  @override
  State<EnhancedReceiptVerificationScreen> createState() =>
      _EnhancedReceiptVerificationScreenState();
}

class _EnhancedReceiptVerificationScreenState
    extends State<EnhancedReceiptVerificationScreen> {
  late TextEditingController _textController;
  late String _originalText;
  bool _isProcessing = false;
  Map<String, dynamic>? _selectedTrustedPartner;
  double? _correctedTotal;

  @override
  void initState() {
    super.initState();
    // Convert text blocks to editable text, preserving order
    _originalText = widget.extractedTextBlocks
        .map((block) => block.text)
        .join('\n');
    _textController = TextEditingController(text: _originalText);
  }

  Widget _buildReceiptPreview() {
    if (widget.extractedTextBlocks.isEmpty) {
      return const Center(
        child: Text(
          'No text extracted from receipt',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Find the bounds of all text blocks
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final block in widget.extractedTextBlocks) {
      minX = minX < block.x ? minX : block.x;
      minY = minY < block.y ? minY : block.y;
      maxX = maxX > block.x + block.width ? maxX : block.x + block.width;
      maxY = maxY > block.y + block.height ? maxY : block.y + block.height;
    }

    final receiptWidth = maxX - minX;
    final receiptHeight = maxY - minY;

    // Display the captured image with text overlay
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 300),
      child: Stack(
        children: [
          // Background image
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: MemoryImage(Uint8List.fromList(widget.imageBytes)),
                fit: BoxFit.contain,
              ),
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          // Text overlay with discount highlighting
          ...widget.extractedTextBlocks.map((block) {
            // Calculate relative position within the preview container
            final relativeX = (block.x - minX) / receiptWidth;
            final relativeY = (block.y - minY) / receiptHeight;

            // Check if this text block contains discount items
            bool hasDiscount = false;
            Color highlightColor = Colors.red; // Default red for regular text

            for (final discountMatch in widget.discountMatches.entries) {
              if (block.text.toLowerCase().contains(
                    discountMatch.key.toLowerCase(),
                  ) ||
                  discountMatch.key.toLowerCase().contains(
                    block.text.toLowerCase(),
                  )) {
                hasDiscount = true;
                highlightColor = Colors.green; // Green for discount items
                break;
              }
            }

            return Positioned(
              left: relativeX * MediaQuery.of(context).size.width * 0.8,
              top: relativeY * 280,
              child: Container(
                width:
                    (block.width / receiptWidth) *
                    MediaQuery.of(context).size.width *
                    0.8,
                height: (block.height / receiptHeight) * 280,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: highlightColor,
                    width: hasDiscount ? 3 : 2,
                  ),
                  color: hasDiscount
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.1),
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  block.text,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: hasDiscount ? Colors.white : Colors.red,
                    fontWeight: FontWeight.bold,
                    backgroundColor: hasDiscount
                        ? Colors.green.withValues(alpha: 0.8)
                        : Colors.white.withValues(alpha: 0.7),
                    shadows: hasDiscount
                        ? [const Shadow(color: Colors.black, blurRadius: 2)]
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDiscountSummary() {
    if (widget.availableDiscounts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.identifiedBusinessName != null
                    ? Icons.store
                    : Icons.info,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.identifiedBusinessName != null
                    ? 'Discounts Available at ${widget.identifiedBusinessName}'
                    : 'Available Discounts',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.availableDiscounts.map((discount) {
            final hasMatches =
                widget.discountMatches.containsKey(discount.name) ||
                widget.discountMatches.values.any(
                  (matches) => matches.contains(discount.name),
                );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasMatches ? Colors.green[50] : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: hasMatches ? Colors.green : Colors.grey[300]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasMatches ? Icons.check_circle : Icons.discount,
                    color: hasMatches ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          discount.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasMatches
                                ? Colors.green[800]
                                : Colors.black,
                          ),
                        ),
                        Text(
                          discount.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: hasMatches
                                ? Colors.green[600]
                                : Colors.grey[600],
                          ),
                        ),
                        Text(
                          discount.percentage > 0
                              ? '${discount.percentage}% off'
                              : 'R${discount.fixedAmount} off',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: hasMatches
                                ? Colors.green[700]
                                : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasMatches)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'APPLIED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _processReceipt() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter receipt text to process'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // First, parse the receipt to get the extracted total
      final receiptData = await widget.receiptParser.parseReceiptFromText(
        _textController.text,
        widget.imageBytes,
      );

      // Show total verification dialog
      final shouldProceed = await _showTotalVerificationDialog(
        receiptData.total,
      );

      if (!shouldProceed || !mounted) {
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      // Check if text was corrected and save for learning
      final currentText = _textController.text;
      if (currentText != _originalText && currentText.trim().isNotEmpty) {
        // Save correction for machine learning improvement
        await widget.receiptParser.saveTextCorrection(
          originalText: _originalText,
          correctedText: currentText,
          imageBytes: widget.imageBytes,
          businessName: widget.identifiedBusinessName,
        );
      }

      // Save total correction for learning if it was corrected
      if (_correctedTotal != null && _correctedTotal != receiptData.total) {
        await _saveTotalCorrection(receiptData.total, _correctedTotal!);
      }

      if (mounted) {
        // Navigate back with processed data
        Navigator.of(context).pop({
          'receiptData': receiptData,
          'imageBytes': widget.imageBytes,
          'rawText': _textController.text,
          'identifiedBusiness': widget.identifiedBusinessName,
          'availableDiscounts': widget.availableDiscounts,
          'discountMatches': widget.discountMatches,
          'selectedTrustedPartner': _selectedTrustedPartner,
          'correctedTotal': _correctedTotal,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<bool> _showTotalVerificationDialog(double extractedTotal) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return TotalVerificationDialog(
              extractedTotal: extractedTotal,
              onCorrect: () {
                _correctedTotal = null; // No correction needed
                Navigator.of(context).pop(true);
              },
              onIncorrect: (double correctedTotal) {
                _correctedTotal = correctedTotal;
                Navigator.of(context).pop(true);
              },
              onCancel: () {
                Navigator.of(context).pop(false);
              },
            );
          },
        ) ??
        false;
  }

  Future<void> _saveTotalCorrection(
    double originalTotal,
    double correctedTotal,
  ) async {
    try {
      // Save the total correction for machine learning improvement
      // This could be stored in a database or sent to a learning service
      await widget.receiptParser.saveTotalCorrection(
        originalTotal: originalTotal,
        correctedTotal: correctedTotal,
        receiptText: _textController.text,
        imageBytes: widget.imageBytes,
        businessName: widget.identifiedBusinessName,
      );
    } catch (e) {
      // Log the error but don't block the flow
      print('Failed to save total correction: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Receipt & Check Discounts'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _processReceipt,
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Process',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Business identification status
              if (widget.identifiedBusinessName != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.store, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Identified: ${widget.identifiedBusinessName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Business not identified - select trusted partner for approval',
                              style: TextStyle(color: Colors.orange),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Trusted partner selection dropdown
                    if (widget.availableTrustedPartners != null &&
                        widget.availableTrustedPartners!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Trusted Partner for Approval:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: _selectedTrustedPartner,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                hintText: 'Choose a trusted partner...',
                              ),
                              items: widget.availableTrustedPartners!.map((
                                partner,
                              ) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: partner,
                                  child: Text(
                                    partner['name'] as String? ??
                                        'Unknown Business',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (partner) {
                                setState(() {
                                  _selectedTrustedPartner = partner;
                                });
                              },
                              validator: (value) {
                                if (widget.identifiedBusinessName == null &&
                                    value == null) {
                                  return 'Please select a trusted partner';
                                }
                                return null;
                              },
                            ),
                            if (_selectedTrustedPartner != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Selected: ${_selectedTrustedPartner!['name']}',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    else if (widget.availableTrustedPartners == null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.grey),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Loading trusted partners...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.red),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No trusted partners available for approval',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

              const SizedBox(height: 16),

              // Receipt preview with discount highlights
              _buildReceiptPreview(),

              const SizedBox(height: 16),

              // Discount summary
              _buildDiscountSummary(),

              const SizedBox(height: 16),

              // Text editing area
              const Text(
                'Edit Receipt Text (if needed):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              // Show correction indicator if text was modified
              if (_textController.text != _originalText &&
                  _textController.text.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lightbulb, color: Colors.blue[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Corrections will improve future OCR',
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _textController,
                maxLines: 12,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText:
                      'Receipt text will appear here...\n\nTip: Edit any incorrect text to improve OCR accuracy for future scans.',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  helperText:
                      'Make corrections to help improve future OCR accuracy',
                  helperStyle: TextStyle(color: Colors.blue[600], fontSize: 11),
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                onChanged: (value) {
                  // Optional: Could add real-time feedback here
                },
              ),

              const SizedBox(height: 16),

              // Legend
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Legend:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.square, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Text('Regular text'),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.square, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Text('Discount item'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TotalVerificationDialog extends StatefulWidget {
  final double extractedTotal;
  final VoidCallback onCorrect;
  final Function(double) onIncorrect;
  final VoidCallback onCancel;

  const TotalVerificationDialog({
    super.key,
    required this.extractedTotal,
    required this.onCorrect,
    required this.onIncorrect,
    required this.onCancel,
  });

  @override
  State<TotalVerificationDialog> createState() =>
      _TotalVerificationDialogState();
}

class _TotalVerificationDialogState extends State<TotalVerificationDialog> {
  bool _showCorrectionField = false;
  final TextEditingController _totalController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify Total Amount'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extracted total: R${widget.extractedTotal.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Is this total correct?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (_showCorrectionField) ...[
              TextFormField(
                controller: _totalController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Correct Total Amount',
                  hintText: 'Enter the correct total',
                  prefixText: 'R',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the correct total';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState?.validate() ?? false) {
                          final correctedTotal = double.parse(
                            _totalController.text,
                          );
                          widget.onIncorrect(correctedTotal);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Proceed'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showCorrectionField = false;
                        _totalController.clear();
                      });
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onCorrect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Correct'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showCorrectionField = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Incorrect'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
      ],
    );
  }
}
