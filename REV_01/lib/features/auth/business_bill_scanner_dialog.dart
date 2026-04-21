import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/business_bill_service.dart';

class BusinessBillScannerDialog extends StatefulWidget {
  final String businessId;
  final String businessName;

  const BusinessBillScannerDialog({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  State<BusinessBillScannerDialog> createState() =>
      _BusinessBillScannerDialogState();
}

class _BusinessBillScannerDialogState extends State<BusinessBillScannerDialog> {
  late CameraController _cameraController;
  final BusinessBillService _billService = BusinessBillService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = 'Initializing camera...';
  List<String> _uploadedBills = [];
  bool _showInstructions = true; // Track if instructions overlay is shown

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadExistingBills();
  }

  Future<void> _initializeCamera() async {
    try {
      // Small delay to ensure previous camera is released
      await Future.delayed(const Duration(milliseconds: 500));

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'No camera available';
        });
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController.initialize();
      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Point camera at business bill to scan';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  Future<void> _loadExistingBills() async {
    try {
      final bills = await _billService.getBusinessBills(widget.businessId);
      setState(() {
        _uploadedBills = bills.map((bill) => bill.billUrl).toList();
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _billService.dispose();
    super.dispose();
  }

  Future<void> _captureAndProcessBill() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Capturing bill...';
    });

    try {
      // Capture image from camera
      final XFile imageFile = await _cameraController.takePicture();

      setState(() {
        _statusMessage = 'Processing bill...';
      });

      // Convert captured image to bytes
      final imageBytes = await imageFile.readAsBytes();

      // Upload bill
      await _billService.uploadBusinessBill(
        businessId: widget.businessId,
        businessName: widget.businessName,
        billBytes: imageBytes,
        fileName: 'bill_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Reload bills list
      await _loadExistingBills();

      setState(() {
        _statusMessage =
            'Bill uploaded successfully! Point camera at another bill or close.';
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business bill uploaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to upload bill: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _pickBillFromGallery() async {
    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (imageFile == null) return;

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Uploading bill from gallery...';
      });

      final imageBytes = await imageFile.readAsBytes();

      // Upload bill
      await _billService.uploadBusinessBill(
        businessId: widget.businessId,
        businessName: widget.businessName,
        billBytes: imageBytes,
        fileName: 'bill_gallery_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Reload bills list
      await _loadExistingBills();

      setState(() {
        _statusMessage = 'Bill uploaded successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business bill uploaded from gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to upload bill: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload bill: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(
        8,
      ), // Reduced padding for larger dialog
      child: SizedBox(
        width: double.maxFinite,
        height:
            MediaQuery.of(context).size.height *
            0.95, // Increased from 0.8 to 0.95 for bigger scanner
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
                        const Text(
                          'Business Bill Scanner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.businessName,
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

            // Content
            Expanded(
              child: Stack(
                children: [
                  // Main Scanner Content
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Camera Preview - Made bigger
                        Container(
                          height:
                              MediaQuery.of(context).size.height *
                              0.6, // Increased from 200 to 60% of screen height
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

                        const SizedBox(height: 12),

                        // Status Message
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _statusMessage.contains('successfully')
                                  ? Colors.green
                                  : _statusMessage.contains('Failed')
                                  ? Colors.red
                                  : Colors.black,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isCameraInitialized && !_isProcessing
                                    ? _captureAndProcessBill
                                    : null,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Capture Bill'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: !_isProcessing
                                    ? _pickBillFromGallery
                                    : null,
                                icon: const Icon(Icons.photo_library),
                                label: const Text('From Gallery'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Uploaded Bills Section
                        if (_uploadedBills.isNotEmpty) ...[
                          const Text(
                            'Uploaded Bills:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _uploadedBills.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      _uploadedBills[index],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return const Icon(
                                              Icons.broken_image,
                                            );
                                          },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Instructions Overlay
                  if (_showInstructions)
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '📸 How to scan business bills',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '• Point camera at complete business bills/receipts\n'
                                '• Include logos, headers, and layout elements\n'
                                '• Ensure good lighting and focus\n'
                                '• Capture clear, complete images\n'
                                '• This helps the app automatically recognize your business bills',
                                style: TextStyle(fontSize: 14, height: 1.5),
                                textAlign: TextAlign.left,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showInstructions = false;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'I Understand',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
