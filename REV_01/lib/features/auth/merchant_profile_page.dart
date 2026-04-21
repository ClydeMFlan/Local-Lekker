import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_qr_code.dart';

class MerchantProfilePage extends StatefulWidget {
  const MerchantProfilePage({super.key});

  @override
  State<MerchantProfilePage> createState() => _MerchantProfilePageState();
}

class _MerchantProfilePageState extends State<MerchantProfilePage> {
  final _logger = Logger();
  String? _activationKey;
  Map<String, dynamic>? _tpQrData;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Personal Information
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();

  // Business Information
  final _businessNameController = TextEditingController();
  final _streetController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactNumberController = TextEditingController();

  String? _selectedProvince;
  String? _selectedCategory;
  String? _email; // Read-only

  final List<String> _provinces = [
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

  final List<String> _categories = [
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
    _loadMerchantProfile();
  }

  Future<void> _loadMerchantProfile() async {
    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        _logger.w('No user found');
        return;
      }

      _logger.d('Loading profile for user: ${user.id}');
      _logger.d('User metadata: ${user.userMetadata}');
      _logger.d('User email: ${user.email}');

      // Load user profile data
      var profileResponse = await SupabaseService.instance.client
          .from('profiles')
          .select() // Select ALL columns to see what's available
          .eq('id', user.id)
          .single();

      _logger.d('Profile response: $profileResponse');
      _logger.d('Profile response type: ${profileResponse.runtimeType}');
      _logger.d('Profile response keys: ${profileResponse.keys.toList()}');

      // Log each field individually
      profileResponse.forEach((key, value) {
        _logger.d('Profile field $key = $value (${value.runtimeType})');
      });

      // Check if surname field exists in the response
      if (!profileResponse.containsKey('surname') ||
          profileResponse['surname'] == null ||
          (profileResponse['surname'] as String?)?.isEmpty == true) {
        _logger.d('Surname field missing or empty from profile response');
        _logger.d('Profile surname value: ${profileResponse['surname']}');
        // Try to update the profile to include surname field
        try {
          final userMetadata = user.userMetadata;
          final metadataSurname = userMetadata?['surname'] as String?;

          if (metadataSurname != null && metadataSurname.isNotEmpty) {
            _logger.d('Found surname in user metadata: $metadataSurname');
            await SupabaseService.instance.client
                .from('profiles')
                .update({'surname': metadataSurname})
                .eq('id', user.id);
            _logger.d('Updated profile with surname from metadata');

            // Reload the profile data
            profileResponse = await SupabaseService.instance.client
                .from('profiles')
                .select('id, name, surname, email, role, category, created_at')
                .eq('id', user.id)
                .single();
            _logger.d('Reloaded profile: $profileResponse');
          } else {
            _logger.d('No surname found in user metadata either');
            // No surname in metadata, try to extract from name if it contains space
            final fullName = profileResponse['name'] as String? ?? '';
            if (fullName.contains(' ')) {
              final nameParts = fullName.split(' ');
              if (nameParts.length >= 2) {
                final extractedSurname = nameParts.sublist(1).join(' ');
                _logger.d('Extracting surname from name: $extractedSurname');
                await SupabaseService.instance.client
                    .from('profiles')
                    .update({'surname': extractedSurname})
                    .eq('id', user.id);

                // Reload the profile data
                profileResponse = await SupabaseService.instance.client
                    .from('profiles')
                    .select(
                      'id, name, surname, email, role, category, created_at',
                    )
                    .eq('id', user.id)
                    .single();
                _logger.d(
                  'Reloaded profile after surname extraction: $profileResponse',
                );
              }
            }
          }
        } catch (e) {
          _logger.e('Failed to update profile with surname: $e');
        }
      }

      // Load business profile data
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('*')
          .eq('owner_member_id', user.id)
          .maybeSingle();

      _logger.d('Business response: $businessResponse');
      _logger.d('Business response type: ${businessResponse.runtimeType}');
      if (businessResponse != null) {
        _logger.d('Business response keys: ${businessResponse.keys.toList()}');
        _logger.d(
          'Contact number from business: ${businessResponse['contact_number']}',
        );
        _logger.d(
          'Contact email from business: ${businessResponse['contact_email']}',
        );
      } else {
        _logger.d('No business data found for user');
      }

      if (mounted) {
        setState(() {
          // Personal info
          final fullName = profileResponse['name'] ?? '';
          final surname = profileResponse['surname'] ?? '';

          _logger.d('Full name from DB: $fullName');
          _logger.d('Surname from DB: $surname');

          // If we have a separate surname field, use it
          if (surname.isNotEmpty) {
            _logger.d('Processing separate surname: "$surname"');
            // We have a separate surname, so extract first name from full name
            if (fullName.endsWith(' $surname')) {
              _logger.d('Full name ends with surname, extracting first name');
              // Full name ends with surname, extract first name
              _nameController.text = fullName
                  .substring(0, fullName.length - surname.length - 1)
                  .trim();
            } else if (fullName.contains(' ')) {
              _logger.d('Full name has spaces but doesn\'t end with surname');
              // Full name has spaces but doesn't end with surname, assume first word is first name
              _nameController.text = fullName.split(' ').first;
            } else {
              _logger.d('Full name has no spaces, using as first name');
              // Full name has no spaces, use it as first name
              _nameController.text = fullName;
            }
            _surnameController.text = surname;
            _logger.d(
              'Set name to: "${_nameController.text}", surname to: "${_surnameController.text}"',
            );
          } else {
            _logger.d('No separate surname, splitting full name');
            // No separate surname, try to split the full name
            if (fullName.contains(' ')) {
              final nameParts = fullName.split(' ');
              _nameController.text = nameParts.first;
              _surnameController.text = nameParts.sublist(1).join(' ');
            } else {
              // Only one name, put it in first name field
              _nameController.text = fullName;
              _surnameController.text = '';
            }
            _logger.d(
              'Split result - name: "${_nameController.text}", surname: "${_surnameController.text}"',
            );
          }

          _logger.d('Setting name controller: ${_nameController.text}');
          _logger.d('Setting surname controller: ${_surnameController.text}');

          // Business info
          if (businessResponse != null) {
            _logger.d('Populating business data');
            _businessNameController.text = businessResponse['name'] ?? '';
            _selectedCategory = businessResponse['category'];

            // Parse combined address into individual components
            final address = businessResponse['address'] ?? '';
            _parseAddress(address);

            _contactNumberController.text =
                businessResponse['contact_number'] ?? '';
            _logger.d(
              'Set contact number to: "${_contactNumberController.text}"',
            );
          } else {
            _logger.d('No business data to populate');
          }

          // Set email from profile data
          _email = profileResponse['email'] ?? '';

          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.e('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
      }
    }
  }

  Future<void> _saveProfile() async {
    _logger.d('Starting save profile operation');
    if (!_formKey.currentState!.validate()) {
      _logger.w('Form validation failed');
      return;
    }

    _logger.d('Form validation passed');
    setState(() => _isSaving = true);

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        _logger.w('No user found for save operation');
        return;
      }

      _logger.d('Saving profile for user: ${user.id}');

      // Update personal profile
      final firstName = _nameController.text.trim();
      final surname = _surnameController.text.trim();
      final fullName = surname.isEmpty ? firstName : '$firstName $surname';

      _logger.d(
        'First name: "$firstName", Surname: "$surname", Full name: "$fullName"',
      );

      _logger.d('Updating profiles table...');
      await SupabaseService.instance.client
          .from('profiles')
          .update({
            'name': fullName, // Store full name for backward compatibility
            'surname': surname, // Store surname separately
          })
          .eq('id', user.id);

      _logger.d('Profiles table updated successfully');

      // Update or create business profile
      final businessData = {
        'owner_member_id': user.id,
        'name': _businessNameController.text.trim(),
        'address': _buildAddress(),
        'category': _selectedCategory,
        'contact_number': _contactNumberController.text.trim(),
      };

      _logger.d('Business data to save: $businessData');
      _logger.d('Updating businesses table...');

      await SupabaseService.instance.client
          .from('businesses')
          .upsert(businessData, onConflict: 'owner_member_id');

      _logger.d('Businesses table updated successfully');

      if (mounted) {
        _logger.i('Save operation completed successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _logger.e('Error during save operation: $e');
      _logger.e('Error type: ${e.runtimeType}');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_activationKey != null) ...[
                const SizedBox(height: 24),
                Text(
                  'TP Activation Key',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(_activationKey!),
                const SizedBox(height: 12),
                CustomQrCode(
                  data: _tpQrData!['qr_code'].toString(),
                  logoAssetPath: 'assets/locallekker_logo.png',
                  size: 200.0,
                ),
                // Debug: show raw QR/key data
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'DEBUG: Raw QR/key: $_activationKey',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
              if (_activationKey == null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'DEBUG: _tpQrData = $_tpQrData',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ],
              const Text(
                'Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your first name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Surname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your surname' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _email,
                decoration: const InputDecoration(
                  labelText: 'Email (Cannot be changed)',
                  border: OutlineInputBorder(),
                  enabled: false,
                ),
                enabled: false,
              ),
              const SizedBox(height: 24),
              const Text(
                'Business Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your business name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Business Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) =>
                    value == null ? 'Please select a business category' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(
                  labelText: 'Suburb',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                ),
                items: _provinces
                    .map(
                      (province) => DropdownMenuItem(
                        value: province,
                        child: Text(province),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedProvince = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _parseAddress(String address) {
    if (address.isEmpty) return;

    // Split address by comma and clean up
    final parts = address.split(',').map((part) => part.trim()).toList();

    if (parts.isNotEmpty) _streetController.text = parts[0];
    if (parts.length > 1) _suburbController.text = parts[1];
    if (parts.length > 2) _cityController.text = parts[2];
    if (parts.length > 3) _selectedProvince = parts[3];
  }

  String _buildAddress() {
    final parts = [
      _streetController.text.trim(),
      _suburbController.text.trim(),
      _cityController.text.trim(),
      _selectedProvince ?? '',
    ].where((part) => part.isNotEmpty).toList();

    return parts.join(', ');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _businessNameController.dispose();
    _streetController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }
}
