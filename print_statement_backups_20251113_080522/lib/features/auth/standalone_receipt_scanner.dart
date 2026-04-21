import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import '../../services/receipt_parser_service.dart';
import '../../services/business_bill_service.dart' hide TextBlockData;
import '../../services/discount_service.dart';
import '../../services/supabase_service.dart';
import '../../models/discount.dart';
import '../../services/bill_service.dart';
import 'enhanced_receipt_verification_screen.dart';

class StandaloneReceiptScanner extends StatefulWidget {
  const StandaloneReceiptScanner({super.key});

  @override
  State<StandaloneReceiptScanner> createState() =>
      _StandaloneReceiptScannerState();
}

class _StandaloneReceiptScannerState extends State<StandaloneReceiptScanner>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  late final ReceiptParserService _receiptParser;
  final BusinessBillService _businessBillService = BusinessBillService();
  final DiscountService _discountService = DiscountService();
  final BillService _billService = BillService();

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _isInitializing = false; // Prevent multiple initialization attempts
  bool _isPanoramicMode =
      false; // Toggle between single-shot and panoramic modes
  List<Uint8List> _panoramicImages =
      []; // Store multiple images for panoramic scanning
  double _currentZoom = 1.0; // Current zoom level
  double _maxZoom = 1.0; // Maximum available zoom
  String _scanStatus = 'Initializing camera...';

  // Processed receipt data for bill submission
  Map<String, dynamic>? _processedReceiptResult;
  List<Map<String, dynamic>>? _availableTrustedPartners;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _receiptParser = ReceiptParserService();
    _initializeCamera();
    _loadTrustedPartners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reinitialize camera when app resumes
      if (!_isCameraInitialized &&
          !_isProcessing &&
          !_isInitializing &&
          mounted) {
        _initializeCamera();
      }
    } else if (state == AppLifecycleState.paused) {
      // Dispose camera when app goes to background
      if (_isCameraInitialized && _cameraController != null && mounted) {
        _cameraController!.dispose();
        setState(() {
          _isCameraInitialized = false;
          _scanStatus = 'Camera paused - tap to resume';
        });
      }
    }
  }

  Future<void> _loadTrustedPartners() async {
    try {
      print('Loading trusted partners for receipt verification...');
      final businesses = await SupabaseService.instance.client
          .from('businesses')
          .select('id, name, category, address, created_at')
          .order('name', ascending: true);

      setState(() {
        _availableTrustedPartners = businesses;
      });
      print('Loaded ${businesses.length} trusted partners');
    } catch (e) {
      print('Failed to load trusted partners: $e');
      // Continue without trusted partners - they can still scan receipts
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializing || _isCameraInitialized) {
      print(
        'Camera initialization skipped: initializing=$_isInitializing, initialized=$_isCameraInitialized',
      );
      return;
    }

    print('Starting camera initialization...');
    setState(() {
      _isInitializing = true;
      _scanStatus = 'Initializing camera...';
    });

    try {
      // Request camera permission first
      print('Requesting camera permission...');
      final cameraStatus = await Permission.camera.request();
      print('Camera permission status: $cameraStatus');

      if (cameraStatus != PermissionStatus.granted) {
        print('Camera permission denied - opening settings');
        // Try to open app settings to allow user to grant permission
        await openAppSettings();
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _scanStatus =
                'Camera permission required. Please grant camera access and try again.';
          });
        }
        return;
      }

      print('Getting available cameras...');
      final cameras = await availableCameras();
      print('Found ${cameras.length} cameras');
      for (int i = 0; i < cameras.length; i++) {
        print(
          'Camera $i: ${cameras[i].name}, lens: ${cameras[i].lensDirection}, sensor: ${cameras[i].sensorOrientation}',
        );
      }

      if (cameras.isEmpty) {
        print('No cameras available');
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _scanStatus = 'No camera available';
          });
        }
        return;
      }

      // Dispose existing camera if any
      print('Disposing existing camera...');
      await _cameraController?.dispose();
      _cameraController = null;

      print('Creating camera controller...');
      _cameraController = CameraController(
        cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.medium, // Changed from high to medium
        enableAudio: false,
      );

      print('Initializing camera controller...');
      await _cameraController!.initialize();
      print(
        'Camera controller initialized successfully, value: ${_cameraController!.value.isInitialized}',
      );

      // Get maximum zoom level
      _maxZoom = await _cameraController!.getMaxZoomLevel();
      print('Maximum zoom level: $_maxZoom');

      if (mounted) {
        print('Setting camera as initialized');
        setState(() {
          _isInitializing = false;
          _isCameraInitialized = true;
          _scanStatus = 'Tap the camera button to scan receipt';
        });
      }
    } catch (e) {
      print('Camera initialization failed: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _scanStatus = 'Camera initialization failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _cameraController = null;
    super.dispose();
  }

  /// Toggle between single-shot and panoramic scanning modes
  void _toggleScanMode(bool? value) {
    setState(() {
      _isPanoramicMode = value ?? false;
      _panoramicImages.clear();
      _scanStatus = _isPanoramicMode
          ? 'Panoramic mode: Scan receipt sections from top to bottom'
          : 'Single-shot mode: Capture entire receipt at once';
    });
  }

  /// Handle zoom level changes
  Future<void> _setZoom(double zoom) async {
    if (_cameraController != null && _isCameraInitialized) {
      try {
        await _cameraController!.setZoomLevel(zoom);
        setState(() {
          _currentZoom = zoom;
        });
      } catch (e) {
        print('Failed to set zoom: $e');
      }
    }
  }

  /// Capture a single image for panoramic scanning
  Future<void> _capturePanoramicSection() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _scanStatus = 'Capturing section ${_panoramicImages.length + 1}...';
    });

    try {
      final XFile imageFile = await _cameraController!.takePicture();
      final imageBytes = await imageFile.readAsBytes();

      setState(() {
        _panoramicImages.add(imageBytes);
        _isProcessing = false;
        _scanStatus =
            'Section ${_panoramicImages.length} captured. Continue scanning or process receipt.';
      });
    } catch (e) {
      print('Failed to capture panoramic section: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanStatus = 'Failed to capture section. Try again.';
        });
      }
    }
  }

  /// Process all panoramic images together
  Future<void> _processPanoramicReceipt() async {
    if (_panoramicImages.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _scanStatus = 'Processing ${_panoramicImages.length} receipt sections...';
    });

    try {
      // Combine all panoramic images into a single text extraction
      final allTextBlocks = <TextBlockData>[];

      for (int i = 0; i < _panoramicImages.length; i++) {
        setState(() {
          _scanStatus =
              'Extracting text from section ${i + 1}/${_panoramicImages.length}...';
        });

        final textBlocks = await _receiptParser.extractRawTextBlocksFromReceipt(
          _panoramicImages[i],
        );

        // Add section metadata to each text block
        for (final block in textBlocks) {
          // For panoramic mode, we'll adjust Y coordinates based on section
          // to create a continuous vertical layout
          final adjustedBlock = TextBlockData(
            text: block.text,
            x: block.x,
            y: block.y + (i * 1000.0), // Offset each section vertically
            width: block.width,
            height: block.height,
          );
          allTextBlocks.add(adjustedBlock);
        }
      }

      setState(() {
        _scanStatus = 'Identifying business and checking discounts...';
      });

      // Use the first image for business identification
      String? identifiedBusinessName;
      List<Discount> availableDiscounts = [];
      Map<String, List<String>> discountMatches = {};

      try {
        // Match receipt against calibration data using first image
        identifiedBusinessName = await _businessBillService
            .matchReceiptWithCalibration(_panoramicImages.first);

        if (identifiedBusinessName != null) {
          // Get business ID from name
          final businesses = await SupabaseService.instance.client
              .from('businesses')
              .select('id, name')
              .eq('name', identifiedBusinessName)
              .maybeSingle();

          if (businesses != null) {
            final businessId = businesses['id'] as String;

            // Get available discounts for this trusted partner
            availableDiscounts = await _discountService
                .getTrustedPartnerDiscounts(businessId);

            // Analyze receipt text for discount matches
            discountMatches = await _analyzeDiscountsInReceipt(
              allTextBlocks,
              availableDiscounts,
            );
          }
        }
      } catch (e) {
        print('Business identification failed: $e');
        // Continue without business identification
      }

      if (!mounted) return;

      setState(() {
        _scanStatus = 'Text extracted successfully';
      });

      // Navigate to enhanced verification screen with combined text blocks
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedReceiptVerificationScreen(
            extractedTextBlocks: allTextBlocks,
            imageBytes: _panoramicImages.first, // Use first image as preview
            receiptParser: _receiptParser,
            identifiedBusinessName: identifiedBusinessName,
            availableDiscounts: availableDiscounts,
            discountMatches: discountMatches,
            availableTrustedPartners: _availableTrustedPartners,
          ),
        ),
      );

      if (result != null && mounted) {
        // Store the processed receipt result for bill submission
        setState(() {
          _processedReceiptResult = result;
        });

        // Receipt processed successfully, show result
        final receiptData = result['receiptData'];
        if (receiptData != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Receipt processed: ${receiptData.merchantName} - Total: R${receiptData.total.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Clear panoramic images and reset
      if (mounted) {
        setState(() {
          _panoramicImages.clear();
          _isProcessing = false;
          _scanStatus =
              'Panoramic mode: Scan receipt sections from top to bottom';
        });
      }
    } catch (e) {
      print('Panoramic receipt processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to process panoramic receipt: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isProcessing = false;
          _scanStatus =
              'Panoramic mode: Scan receipt sections from top to bottom';
        });
      }
    }
  }

  /// Clear panoramic images and reset to start over
  void _clearPanoramicImages() {
    setState(() {
      _panoramicImages.clear();
      _scanStatus = 'Panoramic mode: Scan receipt sections from top to bottom';
    });
  }

  /// Submit the processed receipt as a bill
  Future<void> _submitProcessedBill() async {
    if (_processedReceiptResult == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final receiptData = _processedReceiptResult!['receiptData'];
      final imageBytes = _processedReceiptResult!['imageBytes'] as List<int>;
      final identifiedBusiness =
          _processedReceiptResult!['identifiedBusiness'] as String?;
      final availableDiscounts =
          _processedReceiptResult!['availableDiscounts'] as List<Discount>? ??
          [];
      final discountMatches =
          _processedReceiptResult!['discountMatches']
              as Map<String, List<String>>? ??
          {};
      final selectedTrustedPartner =
          _processedReceiptResult!['selectedTrustedPartner']
              as Map<String, dynamic>?;

      // Get current user
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Find the applied discount (first one with matches)
      Discount? appliedDiscount;
      double discountAmount = 0.0;

      for (final discount in availableDiscounts) {
        final discountName = discount.name;
        if (discountMatches.values.any(
          (matches) => matches.contains(discountName),
        )) {
          appliedDiscount = discount;
          if (discount.percentage > 0) {
            discountAmount = receiptData.total * discount.percentage / 100;
          } else if (discount.fixedAmount != null) {
            discountAmount = discount.fixedAmount!;
          }
          break;
        }
      }

      // Upload image to Supabase storage
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final imageUrl = await _billService.uploadReceiptImage(
        currentUser.id,
        imageBytes,
        fileName,
      );

      // Determine the partner ID to use for authorization
      String? partnerId = appliedDiscount?.trustedPartnerId;

      // If no discount was applied and no business was identified,
      // use the manually selected trusted partner
      if (partnerId == null &&
          identifiedBusiness == null &&
          selectedTrustedPartner != null) {
        partnerId = selectedTrustedPartner['id'] as String?;
      }

      // Save processed bill
      await _billService.saveProcessedBill(
        userId: currentUser.id,
        discountId: appliedDiscount?.id,
        partnerId: partnerId ?? '',
        receiptData: receiptData,
        originalTotal: receiptData.total,
        discountAmount: discountAmount,
        discountedTotal: receiptData.total - discountAmount,
        imageUrl: imageUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bill submitted successfully${selectedTrustedPartner != null ? ' to ${selectedTrustedPartner['name']}' : (identifiedBusiness != null ? ' to $identifiedBusiness' : '')}! Awaiting partner approval.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Clear the processed result
        setState(() {
          _processedReceiptResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit bill: $e'),
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

  Future<void> _captureAndProcessReceipt() async {
    if (!_isCameraInitialized || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _scanStatus = 'Capturing image...';
    });

    try {
      // Take picture
      final XFile imageFile = await _cameraController!.takePicture();
      final imageBytes = await imageFile.readAsBytes();

      setState(() {
        _scanStatus = 'Extracting text from receipt...';
      });

      // Extract raw text blocks using Veryfi OCR
      final extractedTextBlocks = await _receiptParser
          .extractRawTextBlocksFromReceipt(imageBytes);

      setState(() {
        _scanStatus = 'Identifying business and checking discounts...';
      });

      // Try to identify the trusted partner
      String? identifiedBusinessName;
      List<Discount> availableDiscounts = [];
      Map<String, List<String>> discountMatches = {};

      try {
        // Match receipt against calibration data
        identifiedBusinessName = await _businessBillService
            .matchReceiptWithCalibration(imageBytes);

        if (identifiedBusinessName != null) {
          // Get business ID from name (we need to query this)
          final businesses = await SupabaseService.instance.client
              .from('businesses')
              .select('id, name')
              .eq('name', identifiedBusinessName)
              .maybeSingle();

          if (businesses != null) {
            final businessId = businesses['id'] as String;

            // Get available discounts for this trusted partner
            availableDiscounts = await _discountService
                .getTrustedPartnerDiscounts(businessId);

            // Analyze receipt text for discount matches
            discountMatches = await _analyzeDiscountsInReceipt(
              extractedTextBlocks,
              availableDiscounts,
            );
          }
        }
      } catch (e) {
        print('Business identification failed: $e');
        // Continue without business identification
      }

      if (!mounted) return;

      setState(() {
        _scanStatus = 'Text extracted successfully';
      });

      // Navigate to enhanced verification screen
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedReceiptVerificationScreen(
            extractedTextBlocks: extractedTextBlocks,
            imageBytes: imageBytes,
            receiptParser: _receiptParser,
            identifiedBusinessName: identifiedBusinessName,
            availableDiscounts: availableDiscounts,
            discountMatches: discountMatches,
            availableTrustedPartners: _availableTrustedPartners,
          ),
        ),
      );

      if (result != null && mounted) {
        // Store the processed receipt result for bill submission
        setState(() {
          _processedReceiptResult = result;
        });

        // Receipt processed successfully, show result
        final receiptData = result['receiptData'];
        if (receiptData != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Receipt processed: ${receiptData.merchantName} - Total: R${receiptData.total.toStringAsFixed(2)}',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Reset processing state
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanStatus = 'Tap the camera button to scan receipt';
        });
      }
    } catch (e) {
      print('Receipt processing failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process receipt: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isProcessing = false;
          _scanStatus = 'Tap the camera button to scan receipt';
        });
      }
    }
  }

  /// Analyze receipt text blocks against available discounts to find matches
  Future<Map<String, List<String>>> _analyzeDiscountsInReceipt(
    List<dynamic> textBlocks,
    List<Discount> availableDiscounts,
  ) async {
    final discountMatches = <String, List<String>>{};

    if (availableDiscounts.isEmpty || textBlocks.isEmpty) {
      return discountMatches;
    }

    // Check for "percentage off all purchases" type discounts
    final percentageAllDiscounts = availableDiscounts
        .where(
          (discount) =>
              discount.percentage > 0 &&
              (discount.name.toLowerCase().contains('all') ||
                  discount.description.toLowerCase().contains('all') ||
                  discount.description.toLowerCase().contains('everything') ||
                  discount.description.toLowerCase().contains('entire')),
        )
        .toList();

    if (percentageAllDiscounts.isNotEmpty) {
      // If there are "all items" percentage discounts, mark all items as discounted
      for (final block in textBlocks) {
        final itemText = block.text?.trim() ?? '';
        if (itemText.isNotEmpty && _isLikelyItemLine(itemText)) {
          discountMatches[itemText] = percentageAllDiscounts
              .map((d) => d.name)
              .toList();
        }
      }
    } else {
      // Analyze individual discounts
      for (final discount in availableDiscounts) {
        final discountKeywords = _extractDiscountKeywords(discount);

        for (final block in textBlocks) {
          final itemText = block.text?.trim().toLowerCase() ?? '';
          if (itemText.isEmpty) continue;

          // Check if this text block matches the discount
          bool matches = false;

          for (final keyword in discountKeywords) {
            if (itemText.contains(keyword.toLowerCase()) ||
                keyword.toLowerCase().contains(itemText)) {
              matches = true;
              break;
            }
          }

          if (matches && _isLikelyItemLine(block.text ?? '')) {
            final displayText = block.text ?? '';
            if (!discountMatches.containsKey(displayText)) {
              discountMatches[displayText] = [];
            }
            discountMatches[displayText]!.add(discount.name);
          }
        }
      }
    }

    return discountMatches;
  }

  /// Extract keywords from discount for matching
  List<String> _extractDiscountKeywords(Discount discount) {
    final keywords = <String>[];

    // Add discount name words
    keywords.addAll(discount.name.split(' '));

    // Add description words (excluding common words)
    final descriptionWords = discount.description
        .split(' ')
        .where(
          (word) =>
              word.length > 2 &&
              ![
                'the',
                'and',
                'for',
                'with',
                'from',
                'this',
                'that',
              ].contains(word.toLowerCase()),
        )
        .toList();
    keywords.addAll(descriptionWords);

    // Add specific product names if mentioned
    if (discount.description.toLowerCase().contains('buy') &&
        discount.description.toLowerCase().contains('get')) {
      // This might be a BOGO or similar - extract product names
      final words = discount.description.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (words[i].toLowerCase() == 'buy' ||
            words[i].toLowerCase() == 'get') {
          if (i + 1 < words.length) {
            keywords.add(words[i + 1]);
          }
        }
      }
    }

    return keywords.where((keyword) => keyword.isNotEmpty).toList();
  }

  /// Check if a text line is likely to be an item line on a receipt
  bool _isLikelyItemLine(String text) {
    final lowerText = text.toLowerCase().trim();

    // Skip headers, footers, and non-item lines
    if (lowerText.contains('total') ||
        lowerText.contains('subtotal') ||
        lowerText.contains('tax') ||
        lowerText.contains('change') ||
        lowerText.contains('cash') ||
        lowerText.contains('card') ||
        lowerText.contains('receipt') ||
        lowerText.contains('thank you') ||
        lowerText.contains('date') ||
        lowerText.contains('time') ||
        lowerText.startsWith('***') ||
        lowerText.startsWith('===') ||
        lowerText.length < 3) {
      return false;
    }

    // Check for price patterns (contains numbers and currency symbols)
    final hasPrice =
        RegExp(r'[\d]+\.[\d]{2}').hasMatch(text) ||
        RegExp(r'R[\d]').hasMatch(text) ||
        text.contains('.');

    // Check for quantity patterns
    final hasQuantity =
        RegExp(r'^\d+\s').hasMatch(text) || RegExp(r'\s\d+$').hasMatch(text);

    return hasPrice || hasQuantity || text.length > 10;
  }

  @override
  Widget build(BuildContext context) {
    print(
      'Building scanner UI - initialized: $_isCameraInitialized, initializing: $_isInitializing, controller: ${_cameraController != null}',
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status text
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_top : Icons.info,
                    color: _isProcessing ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scanStatus,
                      style: TextStyle(
                        color: _isProcessing ? Colors.orange : Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Camera preview
            Expanded(
              child:
                  _isCameraInitialized &&
                      _cameraController != null &&
                      _cameraController!.value.isInitialized
                  ? Stack(
                      children: [
                        CameraPreview(_cameraController!),
                        // Overlay with instructions
                        Container(
                          color: Colors.black.withValues(alpha: 0.3),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 64,
                                  color: Colors.white,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Position receipt within frame',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Ensure text is clear and well-lit',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _scanStatus,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                          if (_isInitializing) ...[
                            const SizedBox(height: 8),
                            const Text('Initializing camera...'),
                          ],
                          if (_isCameraInitialized &&
                              _cameraController != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Controller exists but not initialized: ${_cameraController!.value.isInitialized}',
                            ),
                          ],
                          if (!_isInitializing && !_isCameraInitialized) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _initializeCamera,
                              child: const Text('Retry Camera Initialization'),
                            ),
                          ],
                        ],
                      ),
                    ),
            ),

            // Zoom controls (only show when camera is initialized)
            if (_isCameraInitialized && _cameraController != null) ...[
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                    Expanded(
                      child: Slider(
                        value: _currentZoom,
                        min: 1.0,
                        max: _maxZoom,
                        divisions: (_maxZoom - 1.0) ~/ 0.1,
                        onChanged: _setZoom,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            // Bottom controls with padding for navigation bar
            Container(
              padding: EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                16.0 +
                    MediaQuery.of(
                      context,
                    ).padding.bottom, // Add bottom safe area
              ),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mode toggle
                  if (_isCameraInitialized) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Single Shot'),
                        Switch(
                          value: _isPanoramicMode,
                          onChanged: _toggleScanMode,
                          activeColor: Colors.green,
                        ),
                        const Text('Panoramic'),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Status text
                  if (_isPanoramicMode) ...[
                    Text(
                      _panoramicImages.isEmpty
                          ? 'Panoramic mode: Scan receipt sections from top to bottom'
                          : 'Sections captured: ${_panoramicImages.length}. Continue scanning or process.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Submit bill section (shown when receipt is processed)
                  if (_processedReceiptResult != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Receipt Processed Successfully!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : _submitProcessedBill,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.send),
                            label: Text(
                              _isProcessing
                                  ? 'Submitting...'
                                  : 'Submit Bill for Approval',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cancel button
                      ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                      ),

                      // Panoramic mode buttons
                      if (_isPanoramicMode) ...[
                        // Capture section button
                        ElevatedButton.icon(
                          onPressed: _isProcessing || !_isCameraInitialized
                              ? null
                              : _capturePanoramicSection,
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text('Capture Section'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),

                        // Process button (only show if we have images)
                        if (_panoramicImages.isNotEmpty) ...[
                          ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : _processPanoramicReceipt,
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: Text(
                              _isProcessing
                                  ? 'Processing...'
                                  : 'Process Receipt',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isProcessing
                                  ? Colors.orange
                                  : Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],

                        // Clear button
                        if (_panoramicImages.isNotEmpty) ...[
                          IconButton(
                            onPressed: _clearPanoramicImages,
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear captured sections',
                            color: Colors.red,
                          ),
                        ],
                      ] else ...[
                        // Single shot capture button
                        ElevatedButton.icon(
                          onPressed: _isProcessing || !_isCameraInitialized
                              ? null
                              : _captureAndProcessReceipt,
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.camera_alt),
                          label: Text(
                            _isProcessing ? 'Processing...' : 'Scan Receipt',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isProcessing
                                ? Colors.orange
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
