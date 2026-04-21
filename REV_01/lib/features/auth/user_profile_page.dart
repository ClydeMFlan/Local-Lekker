import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();

  // Personal Information Controllers
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();

  // Address Information Controllers
  final _streetController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();

  // Contact Information Controllers
  final _contactController = TextEditingController();

  // Personal Details
  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedEthnicity;
  String? _selectedProvince;

  // Dropdown Options (matching signup page)
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _ethnicities = [
    'Black',
    'White',
    'Coloured',
    'Indian',
    'Other',
  ];
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

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _streetController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      // First check if user is authenticated
      final currentUser = SupabaseService.instance.getCurrentUser();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in to access your profile'),
            ),
          );
          Navigator.of(context).pop(); // Go back to previous screen
        }
        return;
      }

      _logger.i('Loading profile for user: ${currentUser.email}');
      _logger.d('User ID: ${currentUser.id}');
      _logger.d(
        'User role from auth metadata: ${currentUser.userMetadata?['user_type']}',
      );

      // Debug: Check what profile data exists
      await SupabaseService.instance.debugUserProfile();

      final supabaseService = SupabaseService.instance;
      final profileData = await supabaseService.getUserProfile();

      _logger.d('Raw profile data from database: $profileData');

      if (profileData != null) {
        // Profile exists, load all the data that matches signup fields
        _logger.i('Profile found, loading data...');
        _logger.d('Profile data: $profileData');

        // Update all form fields with loaded data
        setState(() {
          // Personal Information
          _nameController.text = profileData['name'] ?? '';
          _surnameController.text = profileData['surname'] ?? '';
          _emailController.text = profileData['email'] ?? '';

          // Address Information
          _streetController.text = profileData['street'] ?? '';
          _suburbController.text = profileData['suburb'] ?? '';
          _cityController.text = profileData['city'] ?? '';

          // Contact Information
          _contactController.text = profileData['contact'] ?? '';

          // Personal Details - ensure values are valid for dropdowns
          _selectedGender = _validateDropdownValue(
            profileData['gender'],
            _genders,
          );
          _selectedEthnicity = _validateDropdownValue(
            profileData['ethnicity'],
            _ethnicities,
          );
          _selectedProvince = _validateDropdownValue(
            profileData['province'],
            _provinces,
          );

          // Parse date of birth if it exists
          if (profileData['date_of_birth'] != null) {
            try {
              _selectedDate = DateTime.parse(profileData['date_of_birth']);
            } catch (e) {
              _logger.e('Error parsing date of birth: $e');
              _selectedDate = null;
            }
          }
        });

        // Ensure form rebuilds with new data
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _formKey.currentState?.reset();
          }
        });

        _logger.i(
          'Profile data successfully loaded and prefilled in form fields',
        );
        _logger.d(
          'Name: ${_nameController.text}, Email: ${_emailController.text}',
        );
        _logger.d('Gender: $_selectedGender, Province: $_selectedProvince');
      } else {
        // Profile doesn't exist, create initial profile
        _logger.i('Profile not found, creating initial profile...');
        final created = await supabaseService.createInitialUserProfile();

        if (created) {
          _logger.i('Initial profile created, loading data...');
          // Try loading again after creation
          final newProfileData = await supabaseService.getUserProfile();
          if (newProfileData != null) {
            setState(() {
              // Personal Information
              _nameController.text = newProfileData['name'] ?? '';
              _surnameController.text = newProfileData['surname'] ?? '';
              _emailController.text = newProfileData['email'] ?? '';

              // Address Information
              _streetController.text = newProfileData['street'] ?? '';
              _suburbController.text = newProfileData['suburb'] ?? '';
              _cityController.text = newProfileData['city'] ?? '';

              // Contact Information
              _contactController.text = newProfileData['contact'] ?? '';

              // Personal Details - ensure values are valid for dropdowns
              _selectedGender = _validateDropdownValue(
                newProfileData['gender'],
                _genders,
              );
              _selectedEthnicity = _validateDropdownValue(
                newProfileData['ethnicity'],
                _ethnicities,
              );
              _selectedProvince = _validateDropdownValue(
                newProfileData['province'],
                _provinces,
              );

              // Parse date of birth if it exists
              if (newProfileData['date_of_birth'] != null) {
                try {
                  _selectedDate = DateTime.parse(
                    newProfileData['date_of_birth'],
                  );
                } catch (e) {
                  _logger.e('Error parsing date of birth: $e');
                  _selectedDate = null;
                }
              }
            });

            // Ensure form rebuilds with new data
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _formKey.currentState?.reset();
              }
            });

            _logger.i('Initial profile data successfully loaded and prefilled');
            _logger.d(
              'Name: ${_nameController.text}, Email: ${_emailController.text}',
            );
          } else {
            _logger.e('Failed to load profile after creation');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load profile after creation'),
                ),
              );
            }
          }
        } else {
          _logger.e('Failed to create initial profile');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create profile')),
            );
          }
        }
      }
    } catch (e) {
      _logger.e('Error loading user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper method to validate dropdown values
  String? _validateDropdownValue(String? value, List<String> validOptions) {
    if (value == null || value.isEmpty) return null;
    return validOptions.contains(value) ? value : null;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ??
          DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isSaving = true);

      final supabaseService = SupabaseService.instance;

      // Save ALL profile fields that match what is stored in Supabase during signup
      final profileData = {
        // Personal Information (matches signup)
        'name': _nameController.text.trim(),
        'surname': _surnameController.text.trim(),

        // Address Information (matches signup)
        'street': _streetController.text.trim(),
        'suburb': _suburbController.text.trim(),
        'city': _cityController.text.trim(),

        // Contact Information (matches signup)
        'contact': _contactController.text.trim(),

        // Personal Details (matches signup)
        'gender': _selectedGender,
        'ethnicity': _selectedEthnicity,
        'province': _selectedProvince,
        'date_of_birth': _selectedDate?.toIso8601String(),
      };

      _logger.i(
        'Saving complete profile data (matching signup fields): $profileData',
      );

      final currentUser = supabaseService.client.auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      await supabaseService.updateUserProfile(
        userId: currentUser.id,
        profileData: profileData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.of(context).pop(); // Close the profile screen
      }
    } catch (e) {
      _logger.e('Error saving user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: ${e.toString()}')),
        );
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
        appBar: AppBar(title: const Text('User Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
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
              // Debug info (remove in production)
              if (_nameController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Profile loaded for: ${_emailController.text}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // Personal Information Section
              _buildSectionHeader('Personal Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(
                  labelText: 'Surname',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your surname' : null,
              ),
              const SizedBox(height: 16),

              // Personal Details Section
              _buildSectionHeader('Personal Details'),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date of Birth',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? 'No date selected'
                                : 'Selected: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                          ),
                        ),
                        TextButton(
                          onPressed: _selectDate,
                          child: const Text('Pick Date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) =>
                    value == null ? 'Please select your gender' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedEthnicity,
                decoration: const InputDecoration(
                  labelText: 'Ethnicity',
                  border: OutlineInputBorder(),
                ),
                items: _ethnicities.map((ethnicity) {
                  return DropdownMenuItem(
                    value: ethnicity,
                    child: Text(ethnicity),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedEthnicity = value),
                validator: (value) =>
                    value == null ? 'Please select your ethnicity' : null,
              ),
              const SizedBox(height: 16),

              // Address Information Section
              _buildSectionHeader('Address Information'),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your street address'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(
                  labelText: 'Suburb',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your suburb' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your city' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(),
                ),
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProvince = value),
                validator: (value) =>
                    value == null ? 'Please select your province' : null,
              ),
              const SizedBox(height: 16),

              // Contact Information Section
              _buildSectionHeader('Contact Information'),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your contact number'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                readOnly: true, // Email is not editable
                enabled: false,
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Profile Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
