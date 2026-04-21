import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../services/paystack_service.dart';
import '../../services/admin_service.dart';
import '../../services/notification_service.dart';
import 'change_password_page.dart';
import 'trusted_partner_home_page.dart';
import 'deactivation_confirmation_page.dart';
import 'package:flutter/foundation.dart';
import '../trusted_partner/tp_payment_terms_page.dart';

class BusinessProfilePage extends StatefulWidget {
  final String? initialBusinessName;
  final String? initialName;
  final String? initialAddress;
  final String? initialContactEmail;
  final String? initialContactNumber;
  final String? initialCategory;
  final String? initialLogoPath;
  final bool requireCompletion; // New flag for first-time setup
  // Latitude/longitude removed - not needed

  const BusinessProfilePage({
    super.key,
    this.initialBusinessName,
    this.initialName,
    this.initialAddress,
    this.initialContactEmail,
    this.initialContactNumber,
    this.initialCategory,
    this.initialLogoPath,
    this.requireCompletion =
        false, // Default to false for backward compatibility
    // Lat/lng parameters removed
  });

  @override
  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactNumberController;
  // Social media handles
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _websiteController;
  late final TextEditingController _businessEmailController;
  // Latitude/longitude removed - not needed
  // Note: businessId no longer required for bank accounts; logos may still use returned id
  String? _selectedCategory;
  String? _selectedProvince;
  String? _selectedCity;
  bool _isLoading = true; // Add loading state
  String? _trustedPartnerKey;
  bool _keyIsUsed = false;
  bool _isRequestingKey = false;
  bool _allowAdminDealCreation = false;

  static const _provinces = [
    'Eastern Cape',
    'Free State',
    'Gauteng',
    'KwaZulu-Natal',
    'Limpopo',
    'Mpumalanga',
    'Northern Cape',
    'North West',
    'Western Cape',
  ];

  static const _citiesByProvince = <String, List<String>>{
    'Eastern Cape': [
      'Bhisho', 'Butterworth', 'Cradock', 'East London', 'Graaff-Reinet',
      'Grahamstown (Makhanda)', 'Jeffreys Bay', 'King William\'s Town',
      'Mthatha', 'Port Elizabeth (Gqeberha)', 'Queenstown', 'Uitenhage',
    ],
    'Free State': [
      'Bethlehem', 'Bloemfontein', 'Kroonstad', 'Parys',
      'Phuthaditjhaba', 'Sasolburg', 'Virginia', 'Welkom',
    ],
    'Gauteng': [
      'Alberton', 'Benoni', 'Boksburg', 'Brakpan', 'Carletonville',
      'Centurion', 'Germiston', 'Johannesburg', 'Krugersdorp', 'Midrand',
      'Pretoria', 'Randburg', 'Roodepoort', 'Sandton', 'Soweto',
      'Springs', 'Vanderbijlpark', 'Vereeniging',
    ],
    'KwaZulu-Natal': [
      'Ballito', 'Durban', 'Empangeni', 'Eshowe', 'Ladysmith',
      'Margate', 'Newcastle', 'Pietermaritzburg', 'Pinetown',
      'Port Shepstone', 'Richards Bay', 'Ulundi', 'Umhlanga',
    ],
    'Limpopo': [
      'Bela-Bela', 'Giyani', 'Lephalale', 'Louis Trichardt (Makhado)',
      'Mokopane', 'Musina', 'Phalaborwa', 'Polokwane', 'Thohoyandou',
      'Tzaneen',
    ],
    'Mpumalanga': [
      'Barberton', 'Bethal', 'Ermelo', 'Middelburg',
      'Nelspruit (Mbombela)', 'Secunda', 'Standerton',
      'Witbank (Emalahleni)',
    ],
    'Northern Cape': [
      'De Aar', 'Kathu', 'Kimberley', 'Kuruman', 'Springbok', 'Upington',
    ],
    'North West': [
      'Brits', 'Klerksdorp', 'Lichtenburg', 'Mahikeng',
      'Potchefstroom', 'Rustenburg',
    ],
    'Western Cape': [
      'Beaufort West', 'Cape Town', 'George', 'Hermanus', 'Knysna',
      'Mossel Bay', 'Oudtshoorn', 'Paarl', 'Saldanha', 'Somerset West',
      'Stellenbosch', 'Swellendam', 'Worcester',
    ],
  };

  // Logo state
  String? _existingLogoUrl;
  String? _selectedLogoPath;
  final ImagePicker _picker = ImagePicker();

  // Paystack subaccount setup fields
  late final TextEditingController _accountHolderController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  bool _hasPaystackSubaccount = false;
  bool _paymentTermsAccepted = false;

  final List<String> _categories = [
    'General',
    'Retail',
    'Food & Beverage',
    'Services',
    'Health',
    'Education',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialBusinessName ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialAddress ?? '',
    );
    _contactEmailController = TextEditingController(
      text: widget.initialContactEmail ?? '',
    );
    _contactNumberController = TextEditingController(
      text: widget.initialContactNumber ?? '',
    );
    // Initialize social media controllers
    _facebookController = TextEditingController();
    _instagramController = TextEditingController();
    _websiteController = TextEditingController();
    _businessEmailController = TextEditingController();
    // Lat/lng initialization removed
    // Validate initial category is in the list, fallback to 'General'
    _selectedCategory =
        widget.initialCategory != null &&
            _categories.contains(widget.initialCategory)
        ? widget.initialCategory
        : 'General';
    _selectedLogoPath = widget.initialLogoPath; // Initialize logo path

    // Initialize Paystack subaccount controllers
    _accountHolderController = TextEditingController();
    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();

    // Load existing data if no initial values provided
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    // Only load if no initial values were provided (not during signup)
    if (widget.initialBusinessName == null &&
        widget.initialName == null &&
        widget.initialAddress == null) {
      try {
        final user = SupabaseService.instance.getCurrentUser();
        if (user != null) {
          // Load business data with timeout (including logo_url)
          final businessResponse = await SupabaseService.instance.client
              .from('businesses')
              .select(
                'name, address, city, contact_email, contact_number, category, logo_url, allow_admin_deal_creation, facebook_handle, instagram_handle, website_url, business_email',
              )
              .eq('owner_member_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Load profile data with timeout
          final profileResponse = await SupabaseService.instance.client
              .from('profiles')
              .select(
                'name, surname, email, contact, street, suburb, city, province, partner_payment_terms_accepted',
              )
              .eq('id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Load trusted partner key and banking details status
          final tpResponse = await SupabaseService.instance.client
              .from('trusted_partners')
              .select('unique_key, paystack_subaccount_id, business_name')
              .eq('user_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Check for banking details in trusted_partner_bank_accounts
          final bankingResponse = await SupabaseService.instance.client
              .from('trusted_partner_bank_accounts')
              .select('paystack_recipient_code')
              .eq('user_id', user.id)
              .eq('is_active', true)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          if (mounted) {
            setState(() {
              // Update controllers with loaded data
              if (businessResponse != null) {
                _nameController.text = businessResponse['name'] ?? '';
                _addressController.text = businessResponse['address'] ?? '';
                // Validate category is in the list, fallback to 'General'
                final loadedCategory = businessResponse['category'];
                _selectedCategory = _categories.contains(loadedCategory)
                    ? loadedCategory
                    : 'General';
                _contactEmailController.text =
                    businessResponse['contact_email'] ?? '';
                _contactNumberController.text =
                    businessResponse['contact_number'] ?? '';
                _existingLogoUrl =
                    businessResponse['logo_url']; // Load existing logo
                _allowAdminDealCreation =
                    (businessResponse['allow_admin_deal_creation'] ?? false)
                        as bool;
                // Load social media handles
                _facebookController.text =
                    businessResponse['facebook_handle'] ?? '';
                _instagramController.text =
                    businessResponse['instagram_handle'] ?? '';
                _websiteController.text = businessResponse['website_url'] ?? '';
                _businessEmailController.text =
                    businessResponse['business_email'] ?? '';
                // Initialize province/city from loaded data
                final loadedCity = businessResponse['city'] as String?;
                if (loadedCity != null && loadedCity.isNotEmpty) {
                  for (final entry in _citiesByProvince.entries) {
                    if (entry.value.contains(loadedCity)) {
                      _selectedProvince = entry.key;
                      _selectedCity = loadedCity;
                      break;
                    }
                  }
                }
                // Lat/lng loading removed
              } else if (tpResponse != null &&
                  tpResponse['business_name'] != null) {
                // If no business record exists, pre-fill with trusted partner business name
                _nameController.text = tpResponse['business_name'] ?? '';
              }

              // Store trusted partner key and banking details status
              if (tpResponse != null) {
                _trustedPartnerKey = tpResponse['unique_key'];
                _keyIsUsed = tpResponse['key_used_by'] != null;
              }

              // Check if payment terms have been accepted
              _paymentTermsAccepted =
                  profileResponse?['partner_payment_terms_accepted'] == true;

              // Check if banking details exist
              _hasPaystackSubaccount =
                  (tpResponse != null &&
                      tpResponse['paystack_subaccount_id'] != null) ||
                  (bankingResponse != null &&
                      bankingResponse['paystack_recipient_code'] != null);

              // Use profile address if business address is null
              if (profileResponse != null &&
                  (businessResponse?['address'] == null ||
                      businessResponse?['address'] == '')) {
                final profileAddressParts =
                    [
                          profileResponse['street'],
                          profileResponse['suburb'],
                          profileResponse['city'],
                          profileResponse['province'],
                        ]
                        .where(
                          (part) => part != null && part.toString().isNotEmpty,
                        )
                        .toList();
                final profileAddress = profileAddressParts.join(', ');
                if (profileAddress.isNotEmpty) {
                  _addressController.text = profileAddress;
                }
              }

              // Use profile data as fallback for contact info
              if (profileResponse != null &&
                  businessResponse?['contact_email'] == null) {
                _contactEmailController.text = profileResponse['email'] ?? '';
              }
              if (profileResponse != null &&
                  businessResponse?['contact_number'] == null) {
                _contactNumberController.text =
                    profileResponse['contact'] ?? '';
              }

              // Set loading to false after data is loaded
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        Logger().e('Error loading existing business data: $e');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load business data: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // If initial values are provided (signup flow), not loading
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setAllowAdminDealCreation(bool value) async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;
      setState(() => _allowAdminDealCreation = value);
      await SupabaseService.instance.client
          .from('businesses')
          .update({'allow_admin_deal_creation': value})
          .eq('owner_member_id', user.id);
    } catch (e) {
      setState(() => _allowAdminDealCreation = !_allowAdminDealCreation);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update admin permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Pick logo from gallery with resize
  Future<void> _pickLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedLogoPath = image.path;
        });
      }
    } catch (e) {
      Logger().e('Error picking logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Upload logo to Supabase storage
  Future<String?> _uploadLogo() async {
    if (_selectedLogoPath == null) return _existingLogoUrl;

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) throw Exception('No authenticated user');

      final file = File(_selectedLogoPath!);
      final bytes = await file.readAsBytes();
      final fileExt = _selectedLogoPath!.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '${user.id}/$fileName';

      Logger().i('Uploading logo to partner-logos/$filePath');

      // Upload to partner-logos bucket
      await SupabaseService.instance.client.storage
          .from('partner-logos')
          .uploadBinary(filePath, bytes);

      // Get public URL
      final publicUrl = SupabaseService.instance.client.storage
          .from('partner-logos')
          .getPublicUrl(filePath);

      Logger().i('Logo uploaded successfully, public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      Logger().e('Error uploading logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _requestNewKey() async {
    setState(() => _isRequestingKey = true);
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      final bizName = _nameController.text.isNotEmpty
          ? _nameController.text
          : 'Unknown Business';

      // Notify all admins via notifications table
      final admins = await SupabaseService.instance.client
          .from('profiles')
          .select('id')
          .eq('role', 'admin');

      for (final admin in admins) {
        await NotificationService().createNotification(
          userId: admin['id'] as String,
          title: 'New Key Request',
          message: '$bizName is requesting a new promo key.',
          type: 'key_request',
          data: {
            'tp_user_id': user.id,
            'business_name': bizName,
            'email': user.email,
          },
        );
      }

      // Also send email to admin via the edge function
      try {
        await SupabaseService.instance.client.functions.invoke(
          'send-key-request-email',
          body: {
            'business_name': bizName,
            'email': user.email ?? '',
            'tp_user_id': user.id,
          },
        );
      } catch (e) {
        Logger().w('Edge function email failed (non-blocking): $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New key request sent to admin'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger().e('Failed to request new key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequestingKey = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.requireCompletion
              ? 'Complete Your Profile'
              : 'Business Details',
        ),
        leading: widget.requireCompletion
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  // Navigate back to TP home page
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TrustedPartnerHomePage(),
                    ),
                  );
                },
              ),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Show info banner if profile completion is required
              if (widget.requireCompletion)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please complete your business profile to continue. All fields are required.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter business name'
                    : null,
              ),
              const SizedBox(height: 16),
              // Logo Upload Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Logo (Optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload a logo for your business. This will be shown to members in deals.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedLogoPath != null || _existingLogoUrl != null)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _selectedLogoPath != null
                                ? Image.file(
                                    File(_selectedLogoPath!),
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : (_existingLogoUrl != null
                                      ? Image.network(
                                          _existingLogoUrl!,
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stack) {
                                                return Container(
                                                  width: 120,
                                                  height: 120,
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                  ),
                                                );
                                              },
                                        )
                                      : const SizedBox.shrink()),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _pickLogo,
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Change Logo'),
                              ),
                              if (_selectedLogoPath != null ||
                                  _existingLogoUrl != null)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedLogoPath = null;
                                      _existingLogoUrl = null;
                                    });
                                  },
                                  icon: const Icon(Icons.delete, size: 18),
                                  label: const Text('Remove'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _pickLogo,
                        icon: const Icon(Icons.add_photo_alternate),
                        label: const Text('Upload Logo'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                  ],
                ),
              ),
              // Trusted Partner Key Display
              if (_trustedPartnerKey != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.vpn_key, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Your Trusted Partner Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _trustedPartnerKey!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _trustedPartnerKey!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Key copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copy key',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _keyIsUsed
                            ? 'This key has been used. Request a new key below.'
                            : 'Share this key with a member to give them free access',
                        style: TextStyle(
                          fontSize: 12,
                          color: _keyIsUsed ? Colors.orange.shade700 : Colors.black54,
                        ),
                      ),
                      if (_keyIsUsed) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isRequestingKey ? null : _requestNewKey,
                            icon: _isRequestingKey
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.vpn_key),
                            label: Text(_isRequestingKey ? 'Requesting...' : 'Request New Key'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (_trustedPartnerKey != null) const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedProvince = v;
                    _selectedCity = null;
                  });
                },
                validator: (v) => v == null ? 'Please select a province' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedProvince),
                value: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'City',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: (_selectedProvince != null
                        ? _citiesByProvince[_selectedProvince!] ?? <String>[]
                        : <String>[])
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
                validator: (v) => v == null ? 'Please select a city' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Street Address'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(labelText: 'Contact Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              // Social Media & Web Presence Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.public, color: Colors.purple.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Social Media & Web Presence (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your social media handles and website. Members can click these to connect with your business.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _facebookController,
                      decoration: const InputDecoration(
                        labelText: 'Facebook',
                        hintText: 'facebook.com/yourpage or @yourpage',
                        prefixIcon: Icon(Icons.facebook, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instagramController,
                      decoration: const InputDecoration(
                        labelText: 'Instagram',
                        hintText: '@yourbusiness',
                        prefixIcon: Icon(
                          Icons.camera_alt,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Website',
                        hintText: 'https://yourbusiness.com',
                        prefixIcon: Icon(Icons.language, color: Colors.green),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _businessEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Business Email',
                        hintText: 'info@yourbusiness.com',
                        prefixIcon: Icon(Icons.email, color: Colors.orange),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Allow admin to create deals on my behalf'),
                subtitle: const Text(
                  'Admin can add deals for your business only when enabled',
                ),
                value: _allowAdminDealCreation,
                onChanged: (v) => _setAllowAdminDealCreation(v),
              ),
              const SizedBox(height: 12),
              // Paystack Subaccount Setup Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Banking Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect your bank account to receive payments from members. Click below to securely upload your banking details through Paystack.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    // Always show the button for editing banking details
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showBankingDetailsForm,
                          icon: const Icon(Icons.account_balance),
                          label: Text(
                            _hasPaystackSubaccount
                                ? 'Edit Banking Details'
                                : 'Upload Banking Details',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasPaystackSubaccount
                              ? 'Update your banking details for receiving payments from members'
                              : 'Click to securely enter your banking details for receiving payments',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        if (_hasPaystackSubaccount) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Banking details configured',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Security Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your account password. You will verify with a one-time code before changing it.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ChangePasswordPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Business Details'),
              ),
              const SizedBox(height: 12),
              // Deactivate Account Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.red.shade50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deactivate Business',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Deactivate your business account to stop accepting payments and hide your discounts from members.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: _showDeactivationConfirmation,
                        icon: Icon(Icons.block, color: Colors.red.shade700),
                        label: Text(
                          'Deactivate Business',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red.shade700),
                        ),
                      ),
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

  Future<void> _showDeactivationConfirmation() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => DeactivationConfirmationPage(
          userType: 'trusted_partner',
          onConfirm: _deactivateBusinessAccount,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business deactivated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      // Navigate back to home
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _deactivateBusinessAccount(String reason) async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) throw Exception('No authenticated user');

      final adminService = AdminService();
      await adminService.deactivateTrustedPartner(user.id, reason: reason);

      Logger().i(
        'Business account deactivated for user: ${user.id} with reason: $reason',
      );
    } catch (e) {
      Logger().e('Error deactivating business: $e');
      rethrow;
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // If this is first-time setup, validate that all required fields are completed
    if (widget.requireCompletion) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your business name'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a business category'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your business address'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_contactEmailController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your contact email'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_contactNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your contact number'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Banking details are optional but recommended
      if (!_hasPaystackSubaccount) {
        // Show confirmation dialog
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Banking Details'),
            content: const Text(
              'You haven\'t set up your banking details yet. You won\'t be able to receive payments from members until you add them.\n\nDo you want to continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    // Upload logo if selected
    String? logoUrl = _existingLogoUrl;
    if (_selectedLogoPath != null) {
      logoUrl = await _uploadLogo();
      if (logoUrl == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload logo. Continuing without logo...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    // Also save city directly to businesses table
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user != null && _selectedCity != null) {
        await SupabaseService.instance.client
            .from('businesses')
            .update({'city': _selectedCity})
            .eq('owner_member_id', user.id);
      }
    } catch (e) {
      Logger().w('Could not update city column directly: $e');
    }

    final payload = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'street': _addressController.text.trim(),
      'city': _selectedCity ?? '',
      'province': _selectedProvince ?? '',
      'contact_email': _contactEmailController.text.trim(),
      'contact_number': _contactNumberController.text.trim(),
      if (logoUrl != null) 'logo_url': logoUrl,
      'facebook_handle': _facebookController.text.trim(),
      'instagram_handle': _instagramController.text.trim(),
      'website_url': _websiteController.text.trim(),
      'business_email': _businessEmailController.text.trim(),
      // Lat/lng removed from payload
    };

    try {
      final res = await SupabaseService.instance.completeBusinessProfile(
        payload,
      );
      if (res is Map && res['ok'] == true) {
        // Business ID is returned and can be used for logos if needed: res['business_id']
        final businessId = res['business_id'];

        // Verify logo_url was saved if we uploaded one
        if (logoUrl != null && businessId != null) {
          Logger().i('Verifying logo_url was saved for business: $businessId');
          final verification = await SupabaseService.instance.client
              .from('businesses')
              .select('logo_url')
              .eq('id', businessId)
              .single();
          Logger().i(
            'Database verification - logo_url: ${verification['logo_url']}',
          );
        }

        if (!mounted) return;

        // Show success message for first-time setup
        if (widget.requireCompletion) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Business profile completed successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
        }

        // Use NavigationService to properly route based on user role
        if (mounted) {
          NavigationService().navigateToHomeAfterAuth(context);
        }
      } else {
        final err = res is Map ? res['error'] ?? 'unknown' : res.toString();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Business save failed: $err')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Business save failed: $e')));
    }
  }

  Future<void> _showBankingDetailsForm() async {
    // Require payment terms acceptance before loading banking details
    if (!_paymentTermsAccepted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TpPaymentTermsPage(
            onAccepted: () {
              setState(() => _paymentTermsAccepted = true);
              Navigator.pop(context);
            },
          ),
        ),
      );
      // If they didn't accept, don't proceed
      if (!_paymentTermsAccepted) return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BankingDetailsDialog(
        businessName: _nameController.text.trim(),
        hasExistingDetails: _hasPaystackSubaccount,
      ),
    );

    if (result == true && mounted) {
      // Banking details were successfully saved
      setState(() {
        _hasPaystackSubaccount = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banking details saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactEmailController.dispose();
    _contactNumberController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    _businessEmailController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }
}

class BankingDetailsDialog extends StatefulWidget {
  final String businessName;
  final bool hasExistingDetails;

  const BankingDetailsDialog({
    super.key,
    required this.businessName,
    this.hasExistingDetails = false,
  });

  @override
  State<BankingDetailsDialog> createState() => _BankingDetailsDialogState();
}

class _BankingDetailsDialogState extends State<BankingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  String? _selectedAccountType;
  String? _selectedBankCode;
  bool _isLoading = false;

  final List<String> _accountTypes = ['savings', 'checking'];
  final List<String> _banks = [
    'Absa Bank',
    'Capitec Bank',
    'FNB',
    'Nedbank',
    'Standard Bank',
    'Investec',
    'African Bank',
    'Discovery Bank',
    'Other',
  ];

  final Map<String, String> _bankCodes = {
    'Absa Bank': '632005',
    'Capitec Bank': '470010',
    'FNB': '250655',
    'Nedbank': '198765',
    'Standard Bank': '051001',
    'Investec': '580105',
    'African Bank': '430000',
    'Discovery Bank': '679000',
  };

  @override
  void initState() {
    super.initState();
    _accountNameController.text = widget.businessName;
    if (widget.hasExistingDetails) {
      _loadExistingBankingDetails();
    }
  }

  Future<void> _loadExistingBankingDetails() async {
    if (kDebugMode) {
      print(
        '🔄 DEBUG BankingDetailsDialog: Starting _loadExistingBankingDetails',
      );
    }
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        if (kDebugMode) {
          print('❌ DEBUG BankingDetailsDialog: No authenticated user');
        }
        return;
      }
      if (kDebugMode) {
        print('👤 DEBUG BankingDetailsDialog: Authenticated user: ${user.id}');
      }

      // Get banking details for the user (not tied to a specific business)
      // Banking details are user-level, not business-level
      final paystackService = PaystackService();
      if (kDebugMode) {
        print(
          '🏦 DEBUG BankingDetailsDialog: Calling paystackService.getBankingDetailsForUser',
        );
      }

      final bankingDetails = await paystackService.getBankingDetailsForUser(
        user.id,
      );

      if (kDebugMode) {
        print(
          '📋 DEBUG BankingDetailsDialog: Banking details result: $bankingDetails',
        );
      }

      if (bankingDetails != null && mounted) {
        if (kDebugMode) {
          print(
            '✅ DEBUG BankingDetailsDialog: Populating form with banking details',
          );
        }
        setState(() {
          _accountNameController.text =
              bankingDetails['account_name'] ?? widget.businessName;
          _accountNumberController.text =
              bankingDetails['account_number'] ?? '';
          // Map the bank name from Paystack to our dropdown values
          final mappedBankName = _mapBankNameToDropdown(
            bankingDetails['bank_name'] ?? '',
          );
          _bankNameController.text = mappedBankName;
          _selectedAccountType = bankingDetails['account_type'] ?? 'savings';
          // Load branch code from database (stored separately from Paystack)
          _branchCodeController.text = bankingDetails['branch_code'] ?? '';
        });
        if (kDebugMode) {
          print('📝 DEBUG BankingDetailsDialog: Form populated successfully');
        }
      } else {
        if (kDebugMode) {
          print(
            '❌ DEBUG BankingDetailsDialog: No banking details found or component not mounted',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '💥 DEBUG BankingDetailsDialog: Error loading banking details: $e',
        );
      }
      // If loading fails, just continue with empty form
      // User can still enter details manually
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.hasExistingDetails
            ? 'Update Banking Details'
            : 'Enter Banking Details',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your banking details for receiving payments from members.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name',
                  hintText: 'Business account holder name',
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter account holder name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    _bankNameController.text.isEmpty ||
                        !_banks.contains(_bankNameController.text)
                    ? null
                    : _bankNameController.text,
                decoration: const InputDecoration(labelText: 'Bank Name'),
                items: _banks
                    .map(
                      (bank) =>
                          DropdownMenuItem(value: bank, child: Text(bank)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _bankNameController.text = value ?? '';
                    _selectedBankCode = _bankCodes[value ?? 'Other'];
                  });
                },
                validator: (v) =>
                    v == null || v.isEmpty ? 'Please select your bank' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountType,
                decoration: const InputDecoration(labelText: 'Account Type'),
                items: _accountTypes
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type == 'savings'
                              ? 'Savings Account'
                              : 'Checking Account',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAccountType = value;
                  });
                },
                validator: (v) => v == null || v.isEmpty
                    ? 'Please select account type'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                  labelText: 'Account Number',
                  hintText:
                      'Your business account number (will be masked for security)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter account number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _branchCodeController,
                decoration: const InputDecoration(
                  labelText: 'Branch Code',
                  hintText: '6-digit branch code',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter branch code';
                  if (v.length != 6) return 'Branch code must be 6 digits';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBankingDetails,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Details'),
        ),
      ],
    );
  }

  Future<void> _saveBankingDetails() async {
    if (kDebugMode) {
      print('🔄 DEBUG BankingDetailsDialog: Starting _saveBankingDetails');
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      if (kDebugMode) {
        print('❌ DEBUG BankingDetailsDialog: Form validation failed');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) throw Exception('No authenticated user');
      if (kDebugMode) {
        print('👤 DEBUG BankingDetailsDialog: Authenticated user: ${user.id}');
      }

      // Get business ID from businesses table
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('id')
          .eq('owner_member_id', user.id)
          .maybeSingle();

      if (businessResponse == null || businessResponse['id'] == null) {
        throw Exception(
          'Business not found. Please complete business setup first.',
        );
      }

      final businessId = businessResponse['id'].toString();
      if (kDebugMode) {
        print('🏢 DEBUG BankingDetailsDialog: Found business ID: $businessId');
      }

      // Get bank code from selected bank
      final bankCode =
          _selectedBankCode ?? _bankCodes[_bankNameController.text] ?? '';
      if (kDebugMode) {
        print(
          '🏦 DEBUG BankingDetailsDialog: Bank name: ${_bankNameController.text}, Bank code: $bankCode',
        );
      }

      // Create or update transfer recipient with banking details
      final paystackService = PaystackService();

      // If we have existing details, we need to delete the old recipient first
      // since Paystack doesn't support updating transfer recipients
      if (widget.hasExistingDetails) {
        if (kDebugMode) {
          print(
            '🔄 DEBUG BankingDetailsDialog: Has existing details, checking for old recipient',
          );
        }
        final existingDetails = await paystackService.getBankingDetailsForUser(
          businessId,
        );
        if (existingDetails != null &&
            existingDetails['recipient_code'] != null) {
          if (kDebugMode) {
            print(
              '📋 DEBUG BankingDetailsDialog: Found existing recipient code: ${existingDetails['recipient_code']}',
            );
          }
          // Delete the old recipient from Paystack
          final deleteSuccess = await paystackService.deleteTransferRecipient(
            existingDetails['recipient_code'],
          );
          if (deleteSuccess) {
            if (kDebugMode) {
              print(
                '✅ DEBUG BankingDetailsDialog: Successfully deleted old recipient: ${existingDetails['recipient_code']}',
              );
            }
          } else {
            if (kDebugMode) {
              print(
                '⚠️ DEBUG BankingDetailsDialog: Failed to delete old recipient: ${existingDetails['recipient_code']}',
              );
            }
            // Continue anyway - we'll create a new recipient
          }
        }
      }

      if (kDebugMode) {
        print('📤 DEBUG BankingDetailsDialog: Creating transfer recipient...');
      }
      if (kDebugMode) {
        print('📊 DEBUG BankingDetailsDialog: Payload data:');
      }
      if (kDebugMode) {
        print('   - businessId: $businessId');
      }
      if (kDebugMode) {
        print('   - businessName: ${widget.businessName}');
      }
      if (kDebugMode) {
        print('   - bankCode: $bankCode');
      }
      if (kDebugMode) {
        print('   - accountNumber: ${_accountNumberController.text.trim()}');
      }
      if (kDebugMode) {
        print('   - accountName: ${_accountNameController.text.trim()}');
      }

      final recipientCode = await paystackService.createTransferRecipient(
        businessId: businessId,
        businessName: widget.businessName,
        bankCode: bankCode,
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        accountType:
            _selectedAccountType ?? 'savings', // Pass the selected account type
      );

      if (kDebugMode) {
        print(
          '✅ DEBUG BankingDetailsDialog: Transfer recipient created: $recipientCode',
        );
      }

      if (recipientCode != null) {
        if (kDebugMode) {
          print(
            '💾 DEBUG BankingDetailsDialog: Banking details saved successfully',
          );
        }
        if (kDebugMode) {
          print(
            '🔑 DEBUG BankingDetailsDialog: Recipient code: $recipientCode',
          );
        }

        // Save/update complete banking details to trusted_partner_bank_accounts table
        // Mask account number for security - only store last 4 digits
        final maskedAccountNumber = _maskAccountNumber(
          _accountNumberController.text.trim(),
        );

        // Create Paystack subaccount for split payments
        String? subaccountCode;
        String? verificationMessage;
        try {
          if (kDebugMode) {
            print(
              '💳 DEBUG BankingDetailsDialog: Creating Paystack subaccount with verification...',
            );
          }
          if (kDebugMode) {
            print(
              '🏦 Verifying bank account: ${_accountNumberController.text.trim()} with bank code: $bankCode',
            );
          }

          subaccountCode = await paystackService.createSubaccount(
            businessName: widget.businessName,
            bankCode: bankCode,
            accountNumber: _accountNumberController.text.trim(),
            businessId: businessId,
            percentageCharge:
                0.0, // Partner gets 100% of split (0% platform commission on subaccount)
          );

          if (kDebugMode) {
            print(
              '✅ DEBUG BankingDetailsDialog: Subaccount created: $subaccountCode',
            );
          }

          // Fetch the created subaccount to check verification status
          if (subaccountCode != null) {
            try {
              final subaccountDetails = await paystackService.getSubaccount(
                subaccountCode,
              );
              if (subaccountDetails != null) {
                final settlementBank = subaccountDetails['settlement_bank'];

                if (kDebugMode) {
                  print('✅ Subaccount created successfully:');
                }
                if (kDebugMode) {
                  print('   Settlement Bank: $settlementBank');
                }

                // For South African accounts, verification is not supported by Paystack
                // Show success message if subaccount was created
                if (settlementBank != null) {
                  verificationMessage =
                      '✅ Banking details saved successfully. Subaccount created for split payments.';
                  if (kDebugMode) {
                    print(
                      '✅ Subaccount created with settlement bank configured',
                    );
                  }

                  // Notify admins about new subaccount that needs approval on Paystack
                  try {
                    final businessResponse = await SupabaseService
                        .instance
                        .client
                        .from('businesses')
                        .select('name')
                        .eq('owner_member_id', user.id)
                        .single();

                    final businessName =
                        businessResponse['name'] ?? 'Unknown Business';

                    await NotificationService()
                        .notifyAdminsOfSubaccountApproval(
                          trustedPartnerId: user.id,
                          trustedPartnerName: businessName,
                          businessName: businessName,
                          subaccountCode: subaccountCode,
                          bankName: _bankNameController.text,
                          accountNumber: _maskAccountNumber(
                            _accountNumberController.text.trim(),
                          ),
                        );

                    if (kDebugMode) {
                      print(
                        '✅ Sent subaccount approval notification to admins',
                      );
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      print(
                        '⚠️ Failed to send subaccount approval notification: $e',
                      );
                    }
                    // Don't fail the operation if notification fails
                  }
                } else {
                  verificationMessage =
                      '⚠️ Subaccount created but settlement bank not configured';
                  if (kDebugMode) {
                    print(
                      '⚠️ Subaccount created but missing settlement bank details',
                    );
                  }
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('⚠️ Could not fetch subaccount status: $e');
              }
              // Even if we can't fetch status, if subaccount was created, consider it success
              verificationMessage =
                  '✅ Banking details saved. Subaccount created successfully.';
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '⚠️ DEBUG BankingDetailsDialog: Failed to create subaccount: $e',
            );
          }

          // Parse error to provide specific feedback
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('could not resolve') ||
              errorString.contains('invalid account') ||
              errorString.contains('account number')) {
            verificationMessage =
                '⚠️ Bank verification failed: Invalid account number or bank details';
          } else if (errorString.contains('network') ||
              errorString.contains('connection') ||
              errorString.contains('timeout')) {
            verificationMessage =
                '⚠️ Bank verification failed: Network error. Please check your connection';
          } else if (errorString.contains('already exists') ||
              errorString.contains('duplicate')) {
            verificationMessage =
                '⚠️ Subaccount already exists for this account';
          } else {
            verificationMessage =
                '⚠️ Bank verification failed: ${e.toString().replaceAll('Exception: ', '').replaceAll('Failed to create subaccount: ', '')}';
          }

          if (kDebugMode) {
            print('📝 Verification message: $verificationMessage');
          }

          // Do not proceed without a Paystack subaccount - member payments must settle to the partner
          throw Exception(
            'Unable to create Paystack subaccount. Please fix your banking details and try again.',
          );
        }

        // Stop immediately if Paystack did not return a subaccount code
        if (subaccountCode == null || subaccountCode.isEmpty) {
          throw Exception(
            'Paystack subaccount is required to receive member payments. Please try again.',
          );
        }

        // Persist the subaccount on the trusted_partners record for downstream deal linking
        try {
          await SupabaseService.instance.client
              .from('trusted_partners')
              .update({'paystack_subaccount_id': subaccountCode})
              .eq('user_id', user.id);
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to update trusted_partners with subaccount: $e');
          }
          throw Exception(
            'Banking details saved on Paystack, but we could not link the subaccount to your profile. Please retry.',
          );
        }

        // Save banking details to database
        if (kDebugMode) {
          print('💾 DEBUG BankingDetailsDialog: Saving to database...');
        }
        if (kDebugMode) {
          print('   - user_id: ${user.id}');
        }
        if (kDebugMode) {
          print('   - bank_name: ${_bankNameController.text}');
        }
        if (kDebugMode) {
          print('   - bank_code: $bankCode');
        }
        if (kDebugMode) {
          print('   - recipient_code: $recipientCode');
        }
        if (kDebugMode) {
          print('   - subaccount_code: $subaccountCode');
        }

        try {
          await SupabaseService.instance.client
              .from('trusted_partner_bank_accounts')
              .upsert({
                'user_id': user.id,
                'account_holder_name': _accountNameController.text.trim(),
                'bank_name': _bankNameController.text,
                'bank_code': bankCode,
                'account_type': _selectedAccountType,
                'account_number':
                    maskedAccountNumber, // Store masked account number
                'branch_code': _branchCodeController.text.trim(),
                'paystack_recipient_code': recipientCode,
                'bank_account_type': _selectedAccountType,
                'subaccount_code': subaccountCode,
                'percentage_charge': 90.0,
                'subaccount_active': true,
                'subaccount_created_at': DateTime.now().toIso8601String(),
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'user_id');

          if (kDebugMode) {
            print(
              '✅ DEBUG BankingDetailsDialog: Banking details saved to database successfully',
            );
          }

          // Notify admin about banking details update
          try {
            final businessResponse = await SupabaseService.instance.client
                .from('businesses')
                .select('name')
                .eq('owner_member_id', user.id)
                .single();

            final businessName = businessResponse['name'] ?? 'Unknown Business';

            if (kDebugMode) {
              print(
                '📢 Creating notification for admins: TP=$businessName, Subaccount=$subaccountCode',
              );
            }

            // Use NotificationService to notify all admins with push notification support
            await NotificationService().notifyAdminsOfBankingDetailsUpdate(
              trustedPartnerId: user.id,
              trustedPartnerName: businessName,
              businessName: businessName,
              subaccountCode: subaccountCode,
              bankName: _bankNameController.text,
            );

            if (kDebugMode) {
              print('✅ Admin notifications sent successfully');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Failed to notify admins: $e');
            }
            // Don't fail the entire operation if notification fails
          }
        } catch (dbError) {
          if (kDebugMode) {
            print(
              '❌ DEBUG BankingDetailsDialog: Database insert failed: $dbError',
            );
          }
          throw Exception(
            'Failed to save banking details to database: $dbError. Paystack resources were created (recipient: $recipientCode, subaccount: $subaccountCode).',
          );
        }

        // Verify the banking details were saved to database
        final verifyResponse = await SupabaseService.instance.client
            .from('trusted_partner_bank_accounts')
            .select('paystack_recipient_code, branch_code, bank_account_type')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();

        if (kDebugMode) {
          print(
            '🔍 DEBUG BankingDetailsDialog: Verification - trusted_partner_bank_accounts record: $verifyResponse',
          );
        }

        if (mounted) {
          // Show verification status to user
          if (verificationMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(verificationMessage),
                backgroundColor: verificationMessage.contains('✅')
                    ? Colors.green
                    : Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }

          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to save banking details');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ DEBUG BankingDetailsDialog: Error saving banking details: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save banking details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to mask account number for security
  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) {
      return accountNumber; // If 4 or fewer digits, return as-is
    }
    // Replace all but the last 4 digits with 'xxx'
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    final maskedLength = accountNumber.length - 4;
    final mask = 'x' * maskedLength;
    return '$mask$lastFour';
  }

  // Helper method to map Paystack bank names to our dropdown values
  String _mapBankNameToDropdown(String paystackBankName) {
    // Paystack might return full bank names, but our dropdown has shorter names
    switch (paystackBankName.toLowerCase()) {
      case 'first national bank':
      case 'fnb':
      case 'first national bank (fnb)':
        return 'FNB';
      case 'absa bank':
      case 'absa':
        return 'Absa Bank';
      case 'capitec bank':
      case 'capitec':
        return 'Capitec Bank';
      case 'nedbank':
        return 'Nedbank';
      case 'standard bank':
      case 'standard bank of south africa':
        return 'Standard Bank';
      case 'investec':
      case 'investec bank':
        return 'Investec';
      case 'african bank':
        return 'African Bank';
      case 'discovery bank':
      case 'discovery':
        return 'Discovery Bank';
      default:
        return 'Other'; // For unrecognized banks
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }
}
