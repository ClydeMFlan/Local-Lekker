import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/discount.dart';
import '../../services/receipt_parser_service.dart';
import '../../services/bill_service.dart';
import '../../services/business_bill_service.dart';

class BillScannerDialog extends StatefulWidget {
  final Discount discount;
  final Map<String, dynamic> partner;

  const BillScannerDialog({
    super.key,
    required this.discount,
    required this.partner,
  });

  @override
  State<BillScannerDialog> createState() => _BillScannerDialogState();
}

class _BillScannerDialogState extends State<BillScannerDialog> {
  late CameraController _cameraController;
  final MobileScannerController _scannerController = MobileScannerController();
  final ReceiptParserService _receiptParser = ReceiptParserService();
  final BillService _billService = BillService();
  final BusinessBillService _businessBillService = BusinessBillService();

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  List<Map<String, dynamic>> _extractedItems = [];
  double _originalTotal = 0.0;
  double _discountedTotal = 0.0;
  String _scanStatus = 'Initializing camera...';
  ReceiptData? _receiptData;
  List<int>? _capturedImageBytes;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Force portrait orientation for scanner
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _initializeCamera() async {
    try {
      // Small delay to ensure previous camera is released
      await Future.delayed(const Duration(milliseconds: 500));

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _scanStatus = 'No camera available';
        });
        return;
      }

      // Use the first available camera (usually back camera)
      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
        _scanStatus = 'Point camera at receipt to scan';
      });
    } catch (e) {
      setState(() {
        _scanStatus = 'Failed to initialize camera: $e';
      });
    }
  }

  @override
  void dispose() {
    // Reset orientation preferences when dialog closes
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Dispose camera controller
    _cameraController.dispose();

    // Stop and dispose scanner controller
    _scannerController.stop();
    _scannerController.dispose();

    _receiptParser.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcessReceipt() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _scanStatus = 'Capturing image...';
    });

    try {
      // Capture image from camera using CameraController
      final XFile imageFile = await _cameraController.takePicture();

      setState(() {
        _scanStatus = 'Processing receipt with OCR...';
      });

      // Convert captured image to bytes for OCR processing
      final imageBytes = await imageFile.readAsBytes();
      _capturedImageBytes = imageBytes;

      // Process with OCR
      _receiptData = await _receiptParser.parseReceiptFromBytes(imageBytes);

      // Validate receipt data
      if (_receiptData!.items.isEmpty) {
        throw Exception(
          'No items found in receipt. Please ensure the receipt is clearly visible.',
        );
      }

      // Try to auto-detect business using ML features from stored business bills
      await _tryAutoDetectBusiness(imageBytes);

      // Apply discount logic
      await _applyDiscountLogic();

      // Save processed bill to database
      await _saveProcessedBill();

      setState(() {
        _scanStatus = 'Receipt processed successfully!';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _scanStatus = 'Failed to process receipt. Please try again.';
      });

      String errorMessage = 'Error processing receipt';
      if (e.toString().contains('No items found')) {
        errorMessage =
            'No items detected in receipt. Please ensure the receipt is well-lit and clearly visible.';
      } else if (e.toString().contains('Failed to capture')) {
        errorMessage = 'Failed to capture image. Please try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _applyDiscountLogic() async {
    if (_receiptData == null) return;

    // Convert receipt data to extracted items format
    _extractedItems = _receiptData!.items.map((item) {
      return {
        'name': item.name,
        'quantity': item.quantity,
        'price': item.price,
        'isDiscountItem': true, // Apply discount to all items for now
      };
    }).toList();

    // Calculate original total
    _originalTotal = _receiptData!.total;

    // Apply discount logic
    double discountAmount = 0.0;
    if (widget.discount.percentage > 0) {
      discountAmount = _originalTotal * widget.discount.percentage / 100;
    } else if (widget.discount.fixedAmount != null) {
      discountAmount = widget.discount.fixedAmount!;
    }

    _discountedTotal = _originalTotal - discountAmount;
  }

  /// Try to auto-detect the business using ML features from stored business bills
  Future<void> _tryAutoDetectBusiness(List<int> imageBytes) async {
    try {
      setState(() {
        _scanStatus = 'Analyzing receipt for business matching...';
      });

      // Use business bill service to match receipt against stored bill templates
      final detectedBusinessName = await _businessBillService
          .matchBillInReceipt(imageBytes);

      if (detectedBusinessName != null && detectedBusinessName.isNotEmpty) {
        setState(() {
          _scanStatus = 'Business auto-detected: $detectedBusinessName';
        });
      } else {
        setState(() {
          _scanStatus =
              'Business not auto-detected, proceeding with manual entry';
        });
      }
    } catch (e) {
      // Silently fail - business matching is optional enhancement
      setState(() {
        _scanStatus = 'Proceeding with receipt processing...';
      });
    }
  }

  Future<void> _saveProcessedBill() async {
    if (_receiptData == null) return;

    try {
      // Get user ID from Supabase auth
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Upload receipt image to storage
      String? imageUrl;
      if (_capturedImageBytes != null) {
        imageUrl = await _billService.uploadReceiptImage(
          user.id,
          _capturedImageBytes!,
          'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      await _billService.saveProcessedBill(
        memberId: user.id,
        discountId: widget.discount.id,
        partnerId: widget.partner['id'] ?? '',
        receiptData: _receiptData!,
        originalTotal: _originalTotal,
        discountAmount: _originalTotal - _discountedTotal,
        discountedTotal: _discountedTotal,
        imageUrl: imageUrl,
      );

      setState(() {
        _scanStatus = 'Receipt processed and saved successfully!';
      });
    } catch (e) {
      setState(() {
        _scanStatus = 'Failed to save receipt: $e';
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Receipt - ${widget.discount.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.partner['name'],
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Scanner Section
            if (_extractedItems.isEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Camera Preview - Made responsive to avoid overflow
                      Container(
                        height:
                            MediaQuery.of(context).size.height *
                            0.4, // Reduced from 50% to 40%
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: _isCameraInitialized
                              ? CameraPreview(_cameraController)
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),

                      // Manual Capture Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing
                              ? null
                              : _captureAndProcessReceipt,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Receipt'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status and Instructions
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            Text(
                              _scanStatus,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Position the entire receipt (top to bottom) within the camera frame. For long receipts, hold the device vertically and ensure all text is visible. Tap "Capture Receipt" when ready.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_isProcessing)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: CircularProgressIndicator(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ), // Added bottom padding to prevent overflow
                    ],
                  ),
                ),
              )
            else
              // Results Section
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Extracted Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items List
                      ..._extractedItems.map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item['name'],
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (item['isDiscountItem']) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                'Discount Applied',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        'Qty: ${item['quantity']} × R${item['price'].toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'R${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Divider(),

                      // Totals
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Original Total:',
                            style: TextStyle(fontSize: 16),
                          ),
                          Text(
                            'R${_originalTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Discount (${widget.discount.percentage.toStringAsFixed(0)}%):',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '-R${(_originalTotal - _discountedTotal).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'New Total:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'R${_discountedTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _extractedItems.clear();
                                  _scanStatus =
                                      'Point camera at receipt to scan';
                                });
                              },
                              child: const Text('Scan Again'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                // TODO: Save the processed bill to database
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Discount applied successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: const Text('Apply Discount'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
