import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen for admins to edit an existing Trusted Partner's details.
class AdminEditPartnerScreen extends StatefulWidget {
  final Map<String, dynamic> partner;
  final Map<String, dynamic>? business;

  const AdminEditPartnerScreen({
    super.key,
    required this.partner,
    this.business,
  });

  @override
  State<AdminEditPartnerScreen> createState() => _AdminEditPartnerScreenState();
}

class _AdminEditPartnerScreenState extends State<AdminEditPartnerScreen> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _surnameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _businessNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _contactNumberCtrl;
  late final TextEditingController _contactEmailCtrl;
  late final TextEditingController _facebookCtrl;
  late final TextEditingController _instagramCtrl;
  late final TextEditingController _websiteCtrl;

  String _selectedCategory = 'Restaurant';
  String? _selectedProvince;
  String? _selectedCity;
  bool _isSaving = false;
  String? _selectedLogoPath;
  String? _existingLogoUrl;

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

  static const _categories = [
    'Restaurant',
    'Retail',
    'Health & Beauty',
    'Automotive',
    'Entertainment',
    'Professional Services',
    'Food & Beverage',
    'General',
    'Other',
  ];

  Map<String, dynamic> get _p => widget.partner;
  Map<String, dynamic>? get _biz => widget.business;

  @override
  void initState() {
    super.initState();

    _nameCtrl = TextEditingController(text: _p['name'] ?? '');
    _surnameCtrl = TextEditingController(text: _p['surname'] ?? '');
    _emailCtrl = TextEditingController(text: _p['email'] ?? '');
    _contactCtrl = TextEditingController(text: _p['contact'] ?? '');

    _businessNameCtrl = TextEditingController(
      text: _biz?['name'] ?? _p['business_name'] ?? '',
    );
    _addressCtrl = TextEditingController(text: _biz?['address'] ?? '');

    // Initialize province/city from existing data
    final existingCity = _biz?['city'] ?? _p['business_city'] ?? _p['city'] ?? '';
    if (existingCity.toString().isNotEmpty) {
      for (final entry in _citiesByProvince.entries) {
        if (entry.value.contains(existingCity)) {
          _selectedProvince = entry.key;
          _selectedCity = existingCity;
          break;
        }
      }
    }
    _contactNumberCtrl =
        TextEditingController(text: _biz?['contact_number'] ?? '');
    _contactEmailCtrl =
        TextEditingController(text: _biz?['contact_email'] ?? '');
    _facebookCtrl =
        TextEditingController(text: _biz?['facebook_handle'] ?? '');
    _instagramCtrl =
        TextEditingController(text: _biz?['instagram_handle'] ?? '');
    _websiteCtrl = TextEditingController(text: _biz?['website_url'] ?? '');

    final cat = _biz?['category'] ??
        _p['business_category'] ??
        _p['category'] ??
        'Restaurant';
    _selectedCategory = _categories.contains(cat) ? cat : 'Other';
    _existingLogoUrl = _biz?['logo_url'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _businessNameCtrl.dispose();
    _addressCtrl.dispose();
    _contactNumberCtrl.dispose();
    _contactEmailCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedLogoPath = image.path);
      }
    } catch (e) {
      _logger.e('Error picking logo: $e');
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

  Future<String?> _uploadLogo(String partnerId) async {
    if (_selectedLogoPath == null) return _existingLogoUrl;

    try {
      final file = File(_selectedLogoPath!);
      final bytes = await file.readAsBytes();
      final fileExt = _selectedLogoPath!.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      // Use the partner's ID as the folder so the path matches TP conventions
      final filePath = '$partnerId/$fileName';

      _logger.i('Admin uploading logo to partner-logos/$filePath');

      await _supabase.storage
          .from('partner-logos')
          .uploadBinary(filePath, bytes);

      final publicUrl = _supabase.storage
          .from('partner-logos')
          .getPublicUrl(filePath);

      _logger.i('Logo uploaded successfully: $publicUrl');
      return publicUrl;
    } catch (e) {
      _logger.e('Error uploading logo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload logo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return _existingLogoUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final partnerId = _p['id'] as String;

      // Upload logo if a new one was selected
      final logoUrl = await _uploadLogo(partnerId);

      // 1) Update profiles table
      await _supabase.from('profiles').update({
        'name': _nameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'email': _emailCtrl.text.trim().toLowerCase(),
        'contact': _contactCtrl.text.trim(),
        'city': _selectedCity ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', partnerId);

      // 2) Upsert businesses table
      final bizData = {
        'owner_member_id': partnerId,
        'name': _businessNameCtrl.text.trim(),
        'category': _selectedCategory,
        'city': _selectedCity ?? '',
        'address': _addressCtrl.text.trim(),
        'contact_number': _contactNumberCtrl.text.trim(),
        'contact_email': _contactEmailCtrl.text.trim().isNotEmpty
            ? _contactEmailCtrl.text.trim().toLowerCase()
            : _emailCtrl.text.trim().toLowerCase(),
        'facebook_handle': _facebookCtrl.text.trim(),
        'instagram_handle': _instagramCtrl.text.trim(),
        'website_url': _websiteCtrl.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (logoUrl != null) {
        bizData['logo_url'] = logoUrl;
      }

      if (_biz != null) {
        // Update existing business
        await _supabase
            .from('businesses')
            .update(bizData)
            .eq('owner_member_id', partnerId);
      } else {
        // Create business if it doesn't exist yet
        bizData['created_at'] = DateTime.now().toIso8601String();
        await _supabase.from('businesses').upsert(
          bizData,
          onConflict: 'owner_member_id',
        );
      }

      // 3) Update trusted_partners table business_name
      try {
        await _supabase.from('trusted_partners').update({
          'business_name': _businessNameCtrl.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', partnerId);
      } catch (_) {
        // trusted_partners record may not exist or may not have these columns
      }

      _logger.i('Partner $partnerId updated successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Partner updated successfully'),
          backgroundColor: Colors.teal,
        ),
      );
      Navigator.pop(context, true); // Return true to trigger refresh
    } catch (e) {
      _logger.e('Failed to save partner: $e');
      if (!mounted) return;

      String message = 'Failed to save changes';
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') ||
          errorStr.contains('ClientException') ||
          errorStr.contains('Failed host lookup')) {
        message = 'No internet connection. Please check your network and try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Partner'),
        centerTitle: false,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving...' : 'Save'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Owner Section ──
              _SectionHeader(title: 'Owner Information'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          _inputDecoration('First Name', Icons.person_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _surnameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          _inputDecoration('Surname', Icons.person_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    _inputDecoration('Contact Number', Icons.phone_outlined),
              ),

              const SizedBox(height: 24),

              // ── Logo Section ──
              _SectionHeader(title: 'Business Logo'),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _selectedLogoPath != null
                          ? FileImage(File(_selectedLogoPath!))
                          : (_existingLogoUrl != null
                              ? NetworkImage(_existingLogoUrl!) as ImageProvider
                              : null),
                      child: _selectedLogoPath == null && _existingLogoUrl == null
                          ? Icon(Icons.store, size: 48, color: Colors.grey.shade400)
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _pickLogo,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: Text(
                        _existingLogoUrl != null || _selectedLogoPath != null
                            ? 'Change Logo'
                            : 'Add Logo',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Business Section ──
              _SectionHeader(title: 'Business Information'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _businessNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration:
                    _inputDecoration('Business Name', Icons.store_outlined),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Business name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration:
                    _inputDecoration('Category', Icons.category_outlined),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration:
                    _inputDecoration('Province', Icons.map_outlined),
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
                decoration:
                    _inputDecoration('City', Icons.location_city_outlined),
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
                controller: _addressCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(
                    'Street Address', Icons.location_on_outlined),
              ),

              const SizedBox(height: 24),

              // ── Business Contact Section ──
              _SectionHeader(title: 'Business Contact'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactNumberCtrl,
                keyboardType: TextInputType.phone,
                decoration:
                    _inputDecoration('Business Phone', Icons.phone_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                    'Business Email', Icons.alternate_email_outlined),
              ),

              const SizedBox(height: 24),

              // ── Social Section ──
              _SectionHeader(title: 'Social & Web'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _facebookCtrl,
                decoration:
                    _inputDecoration('Facebook', Icons.facebook_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instagramCtrl,
                decoration: _inputDecoration(
                    'Instagram', Icons.camera_alt_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                decoration:
                    _inputDecoration('Website', Icons.language_outlined),
              ),

              const SizedBox(height: 32),

              // ── Save Button ──
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }
}
