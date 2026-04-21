import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/paystack_service.dart';
import '../../services/qr_code_service.dart';
import 'change_password_page.dart';
import 'payment_method_webview_page.dart';
import 'receipt_book_page.dart';
import 'notifications_page.dart';

// Custom input formatter for expiry date (MM/YY)
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    // Remove any existing slashes
    final cleanText = text.replaceAll('/', '');

    // Only allow digits
    final digitsOnly = cleanText.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 4 digits (MMYY)
    final limitedDigits = digitsOnly.length > 4
        ? digitsOnly.substring(0, 4)
        : digitsOnly;

    // Add slash after month (MM/YY)
    final formattedText = limitedDigits.length >= 2
        ? '${limitedDigits.substring(0, 2)}/${limitedDigits.substring(2)}'
        : limitedDigits;

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class MemberProfilePage extends StatefulWidget {
  const MemberProfilePage({super.key});

  @override
  State<MemberProfilePage> createState() => _MemberProfilePageState();
}

class _MemberProfilePageState extends State<MemberProfilePage> {
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

  // Security: in-app password removed; use Change Password with OTP

  // Trusted Partner Member Controllers
  final _tpKeyController = TextEditingController();
  bool _isTpMember = false;
  bool _isVerifyingKey = false;

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
    _tpKeyController.dispose();
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

      print('Loading profile for user: ${currentUser.email}');
      print('User ID: ${currentUser.id}');
      print(
        'User role from auth metadata: ${currentUser.userMetadata?['user_type']}',
      );

      // Debug: Check what profile data exists
      await SupabaseService.instance.debugUserProfile();

      final supabaseService = SupabaseService.instance;
      final profileData = await supabaseService.getUserProfile();

      print('Raw profile data from database: $profileData');

      if (profileData != null) {
        // Profile exists, load all the data that matches signup fields
        print('Profile found, loading data...');
        print('Profile data: $profileData');

        // Update all form fields with loaded data
        setState(() {
          // Personal Information
          _nameController.text = profileData['name'] ?? '';
          _surnameController.text = profileData['surname'] ?? '';
          _emailController.text = profileData['email'] ?? '';

          // Security Information - in_app_password removed

          // Address Information
          _streetController.text = profileData['street'] ?? '';
          _suburbController.text = profileData['suburb'] ?? '';
          _cityController.text = profileData['city'] ?? '';

          // Contact Information
          _contactController.text = profileData['contact'] ?? '';

          // Trusted Partner Member Information
          _isTpMember = profileData['is_tp_member'] ?? false;

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
              print('Error parsing date of birth: $e');
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

        print('Profile data successfully loaded and prefilled in form fields');
        print('Name: ${_nameController.text}, Email: ${_emailController.text}');
        print('Gender: $_selectedGender, Province: $_selectedProvince');
      } else {
        // Profile doesn't exist, create initial profile
        print('Profile not found, creating initial profile...');
        final created = await supabaseService.createInitialUserProfile();

        if (created) {
          print('Initial profile created, loading data...');
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
                  print('Error parsing date of birth: $e');
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

            print('Initial profile data successfully loaded and prefilled');
            print(
              'Name: ${_nameController.text}, Email: ${_emailController.text}',
            );
          } else {
            print('Failed to load profile after creation');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to load profile after creation'),
                ),
              );
            }
          }
        } else {
          print('Failed to create initial profile');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to create profile')),
            );
          }
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
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

  Future<void> _verifyTrustedPartnerKey() async {
    final key = _tpKeyController.text.trim().toUpperCase();
    if (key.isEmpty || key.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 12-character key'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isVerifyingKey = true);

    try {
      final tpResponse = await SupabaseService.instance.client
          .from('trusted_partners')
          .select('user_id')
          .eq('unique_key', key)
          .maybeSingle();

      if (tpResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid Trusted Partner key'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Key is valid - activate TP member account immediately
        final currentUser = SupabaseService.instance.client.auth.currentUser;
        if (currentUser == null) throw Exception('User not authenticated');

        // Update profile to mark as TP member
        await SupabaseService.instance.updateUserProfile(
          userId: currentUser.id,
          profileData: {'is_tp_member': true},
        );

        // Update membership gateway to indicate TP member activation
        // (No subscription payment required for TP members)
        await SupabaseService.instance.client.from('memberships').upsert({
          'user_id': currentUser.id,
          'role': 'member',
          'gateway': 'trusted_partner_key',
        });

        // Create or reactivate QR code for TP member (permanent, no expiry)
        // Check if QR code already exists
        final existingQrCode = await SupabaseService.instance.client
            .from('user_qr_codes')
            .select()
            .eq('user_id', currentUser.id)
            .maybeSingle();

        if (existingQrCode != null) {
          // Reactivate existing QR code with permanent expiry
          await SupabaseService.instance.client
              .from('user_qr_codes')
              .update({
                'is_active': true,
                'expires_at': DateTime.now()
                    .add(const Duration(days: 36500))
                    .toIso8601String(),
              })
              .eq('user_id', currentUser.id);
        } else {
          // Create new QR code
          final qrCode = await QrCodeService().generateUniqueQrCode(
            currentUser.id,
          );
          await SupabaseService.instance.client.from('user_qr_codes').insert({
            'user_id': currentUser.id,
            'qr_code': qrCode,
            'is_active': true,
            'expires_at': DateTime.now()
                .add(const Duration(days: 36500))
                .toIso8601String(),
          });
        }

        print(
          '✅ TP member account activated successfully with permanent QR code',
        );

        if (mounted) {
          setState(() {
            _isTpMember = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'TP member account activated! Your QR code is now active.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );

          // Navigate back to home after successful activation
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error activating account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingKey = false);
      }
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

        // Security Information removed: in_app_password deprecated

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

        // Note: TP member banking details are NOT needed here
        // Payment method will be saved to Paystack after first purchase
      };

      print(
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
        Navigator.of(context).pop();
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

              // Trusted Partner Member Section
              if (!_isTpMember) ...[
                _buildSectionHeader('Trusted Partner Member'),
                const Text(
                  'If you have a Trusted Partner key, enter it below to activate your membership for free. Your QR code will be activated immediately and you can start making purchases. Payment method will be saved after your first purchase.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tpKeyController,
                        decoration: const InputDecoration(
                          labelText: 'Trusted Partner Key',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                          hintText: 'Enter 12-character key',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 12,
                        enabled: !_isTpMember,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isTpMember || _isVerifyingKey
                          ? null
                          : _verifyTrustedPartnerKey,
                      child: _isVerifyingKey
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Activate'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Banking Details Section removed - TP members use Paystack for payment method storage
              // Payment method will be saved after first purchase

              // Security Section (Change Password via OTP)
              _buildSectionHeader('Security'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Update your account password. You\'ll verify with a one-time code sent to your email before changing it.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
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
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Receipt Book Section
              _buildSectionHeader('Receipt Management'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'View your completed deal receipts and transaction history.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ReceiptBookPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Open Receipt Book'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment Methods Section
              _buildSectionHeader('Banking Details'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Manage your banking details for payments and refunds.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () => _showBankingDetailsDialog(context),
                        icon: const Icon(Icons.account_balance),
                        label: const Text('Edit Banking Details'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'View notifications about your deal authorizations and payments.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const NotificationsPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications),
                        label: const Text('View Notifications'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).primaryColor,
                          ),
                          foregroundColor: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
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

  void _showBankingDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => MemberBankingDetailsDialog(
        onDetailsSaved: () {
          // Refresh profile data if needed
          _loadUserProfile();
        },
      ),
    );
  }
}

class MemberBankingDetailsDialog extends StatefulWidget {
  final VoidCallback? onDetailsSaved;

  const MemberBankingDetailsDialog({super.key, this.onDetailsSaved});

  @override
  State<MemberBankingDetailsDialog> createState() =>
      _MemberBankingDetailsDialogState();
}

class _MemberBankingDetailsDialogState
    extends State<MemberBankingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Payment method selection
  String _selectedPaymentMethod = 'credit_card'; // 'credit_card' or 'banking'

  // Credit Card fields
  final _cardNumberController = TextEditingController();
  final _cardExpiryController = TextEditingController();
  final _cardCvvController = TextEditingController();
  final _cardHolderNameController = TextEditingController();

  // Banking fields
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  String? _selectedAccountType;

  final List<String> _banks = [
    'Absa Bank',
    'FNB',
    'Standard Bank',
    'Nedbank',
    'Capitec Bank',
    'Investec',
    'African Bank',
    'Discovery Bank',
    'Other',
  ];

  final List<String> _accountTypes = ['savings', 'checking'];

  @override
  void initState() {
    super.initState();
    _loadExistingDetails();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardExpiryController.dispose();
    _cardCvvController.dispose();
    _cardHolderNameController.dispose();
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingDetails() async {
    try {
      setState(() => _isLoading = true);

      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) return;

      // Load existing banking details from members_bank_accounts
      final bankingResponse = await SupabaseService.instance.client
          .from('members_bank_accounts')
          .select(
            'account_holder_name, bank_name, account_type, account_number, branch_code, paystack_recipient_code',
          )
          .eq('user_id', user.id)
          .eq('is_active', true)
          .maybeSingle();

      if (bankingResponse != null && mounted) {
        setState(() {
          _selectedPaymentMethod = 'banking';
          _accountNameController.text =
              bankingResponse['account_holder_name'] ?? '';
          _bankNameController.text = bankingResponse['bank_name'] ?? '';
          _accountNumberController.text =
              bankingResponse['account_number'] ?? '';
          _branchCodeController.text = bankingResponse['branch_code'] ?? '';
          _selectedAccountType = bankingResponse['account_type'] ?? 'savings';
        });
      } else {
        // Check for credit card details from members_card_details table
        final cardResponse = await SupabaseService.instance.client
            .from('members_card_details')
            .select('last4, brand, exp_month, exp_year, bank, is_primary')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .order('is_primary', ascending: false)
            .limit(1)
            .maybeSingle();

        if (cardResponse != null && mounted) {
          setState(() {
            _selectedPaymentMethod = 'credit_card';
            _cardNumberController.text =
                '**** **** **** ${cardResponse['last4'] ?? '****'}';
            // Note: Full card details are stored in Paystack, not locally
          });
        }
      }
    } catch (e) {
      print('Error loading banking details: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: const Text('Banking Details'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose your preferred payment method for subscriptions and purchases.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),

              // Payment Method Selection
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Credit Card'),
                      value: 'credit_card',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Banking Details'),
                      value: 'banking',
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) {
                        setState(() {
                          _selectedPaymentMethod = value!;
                        });
                      },
                      dense: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Credit Card Fields
              if (_selectedPaymentMethod == 'credit_card') ...[
                const Text(
                  'Add Credit/Debit Card',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To add a card for payments and renewals, use the secure Paystack payment page.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Initialize Paystack payment for card tokenization
                    try {
                      final user = SupabaseService.instance.getCurrentUser();
                      if (user == null)
                        throw Exception('No authenticated user');

                      setState(() => _isSaving = true);

                      final paystackService = PaystackService();
                      final authUrl = await paystackService
                          .initializePaymentMethod(
                            userId: user.id,
                            userEmail: user.email ?? '',
                            amount: 100, // R1.00 for tokenization
                          );

                      setState(() => _isSaving = false);

                      if (authUrl != null) {
                        // Navigate to PaymentMethodWebViewPage for secure card tokenization
                        Navigator.of(context).pop(); // Close current dialog
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaymentMethodWebViewPage(
                              authorizationUrl: authUrl,
                              userId: user.id,
                              userEmail: user.email ?? '',
                            ),
                          ),
                        );
                        if (result == true && widget.onDetailsSaved != null) {
                          widget.onDetailsSaved!();
                        }
                      } else {
                        throw Exception('Failed to initialize payment');
                      }
                    } catch (e) {
                      setState(() => _isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Failed to initialize card setup: $e',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.credit_card),
                  label: Text(
                    _isSaving ? 'Initializing...' : 'Add Card via Secure Page',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This opens Paystack\'s secure payment page for 3D Secure verification.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                /*
                // OLD DIRECT INPUT - Commented out as it doesn't support 3D Secure
                TextFormField(
                  controller: _cardHolderNameController,
                  decoration: const InputDecoration(
                    labelText: 'Card Holder Name',
                    hintText: 'Name on card',
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter card holder name'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cardNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Card Number',
                    hintText: '1234 5678 9012 3456',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || v.isEmpty
                      ? 'Please enter card number'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cardExpiryController,
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date',
                          hintText: 'MM/YY',
                        ),
                        inputFormatters: [ExpiryDateInputFormatter()],
                        keyboardType: TextInputType.number,
                        validator: (v) => v == null || v.isEmpty
                            ? 'Please enter expiry date'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cardCvvController,
                        decoration: const InputDecoration(
                          labelText: 'CVV',
                          hintText: '123',
                        ),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Please enter CVV' : null,
                      ),
                    ),
                  ],
                ),
                */
              ],

              // Banking Fields
              if (_selectedPaymentMethod == 'banking') ...[
                const Text(
                  'Banking Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
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
                  value: _bankNameController.text.isEmpty
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
                    });
                  },
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please select your bank' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedAccountType,
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
                    hintText: 'Your account number',
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
                    if (v == null || v.isEmpty)
                      return 'Please enter branch code';
                    if (v.length != 6) return 'Branch code must be 6 digits';
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _testVerifyStoredCard,
          child: const Text('Test Cards'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveBankingDetails,
          child: _isSaving
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
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) throw Exception('No authenticated user');

      if (_selectedPaymentMethod == 'credit_card') {
        // Handle credit card setup via Paystack
        await _saveCreditCardDetails(user.id);
      } else {
        // Handle banking details setup
        await _saveBankingDetailsToDatabase(user.id);
      }

      widget.onDetailsSaved?.call();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Banking details saved successfully')),
        );
      }
    } catch (e) {
      print('Error saving banking details: $e');
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
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveCreditCardDetails(String userId) async {
    final paystackService = PaystackService();

    // Parse expiry date
    final expiryParts = _cardExpiryController.text.split('/');
    if (expiryParts.length != 2) {
      throw Exception('Invalid expiry date format. Use MM/YY');
    }

    final expMonth = expiryParts[0].trim();
    final expYear = expiryParts[1].trim();

    // Tokenize the card with Paystack
    final tokenizationResult = await paystackService.tokenizeCard(
      cardNumber: _cardNumberController.text.trim(),
      expiryMonth: expMonth,
      expiryYear: expYear,
      cvv: _cardCvvController.text.trim(),
      cardHolderName: _cardHolderNameController.text.trim(),
      userEmail: SupabaseService.instance.getCurrentUser()?.email ?? '',
      userId: userId,
    );

    if (tokenizationResult != null) {
      // Check if user already has a primary card
      final existingCard = await SupabaseService.instance.client
          .from('members_card_details')
          .select()
          .eq('user_id', userId)
          .eq('is_primary', true)
          .maybeSingle();

      final cardData = {
        'user_id': userId,
        'authorization_code': tokenizationResult['authorization_code'],
        'card_type': tokenizationResult['card_type'] ?? 'card',
        'last4': tokenizationResult['last4'],
        'exp_month': tokenizationResult['exp_month'],
        'exp_year': tokenizationResult['exp_year'],
        'bank': tokenizationResult['bank'] ?? '',
        'brand': tokenizationResult['brand'] ?? '',
        'is_primary': true, // Set as primary for now
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingCard != null) {
        // Update existing primary card
        await SupabaseService.instance.client
            .from('members_card_details')
            .update(cardData)
            .eq('id', existingCard['id']);
      } else {
        // Insert new primary card
        cardData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.instance.client
            .from('members_card_details')
            .insert(cardData);
      }

      print('Credit card tokenized and saved successfully');
    } else {
      throw Exception('Failed to tokenize credit card');
    }
  }

  Future<void> _saveBankingDetailsToDatabase(String userId) async {
    // Create or update banking details for members
    final paystackService = PaystackService();

    // Get bank code from bank name
    final bankCode = _getBankCode(_bankNameController.text);

    print('Creating transfer recipient for member banking details...');

    final recipientCode = await paystackService.createTransferRecipient(
      businessId:
          userId, // Use userId for members (no business association needed)
      businessName: _accountNameController.text,
      bankCode: bankCode,
      accountNumber: _accountNumberController.text.trim(),
      accountName: _accountNameController.text.trim(),
      accountType: _selectedAccountType ?? 'savings',
      isMember: true, // Flag to indicate this is for a member, not a business
    );

    if (recipientCode != null) {
      // Mask account number for security
      final maskedAccountNumber = _maskAccountNumber(
        _accountNumberController.text.trim(),
      );

      // Check if user already has an active bank account
      final existingAccount = await SupabaseService.instance.client
          .from('members_bank_accounts')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      final accountData = {
        'user_id': userId,
        'account_holder_name': _accountNameController.text.trim(),
        'bank_name': _bankNameController.text,
        'account_type': _selectedAccountType,
        'account_number': maskedAccountNumber, // Store masked version
        'branch_code': _branchCodeController.text.trim(),
        'paystack_recipient_code': recipientCode,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingAccount != null) {
        // Update existing active account
        await SupabaseService.instance.client
            .from('members_bank_accounts')
            .update(accountData)
            .eq('id', existingAccount['id']);
      } else {
        // Insert new active account
        accountData['created_at'] = DateTime.now().toIso8601String();
        await SupabaseService.instance.client
            .from('members_bank_accounts')
            .insert(accountData);
      }

      print(
        'Member banking details saved to members_bank_accounts successfully',
      );
    } else {
      throw Exception('Failed to create transfer recipient');
    }
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) {
      return accountNumber;
    }
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    final maskedLength = accountNumber.length - 4;
    final mask = 'x' * maskedLength;
    return '$mask$lastFour';
  }

  String _getBankCode(String bankName) {
    switch (bankName.toLowerCase()) {
      case 'absa bank':
        return '632005';
      case 'fnb':
        return '250655';
      case 'standard bank':
        return '051001';
      case 'nedbank':
        return '198765';
      case 'capitec bank':
        return '470010';
      case 'investec':
        return '580105';
      case 'african bank':
        return '430000';
      case 'discovery bank':
        return '679000';
      default:
        return '632005'; // Default to Absa
    }
  }

  /// Test method to verify that stored card details are accessible in Paystack
  Future<void> _testVerifyStoredCard() async {
    try {
      final userId = SupabaseService.instance.getCurrentUser()?.id;
      if (userId == null) {
        print('No user ID available for testing card verification');
        return;
      }

      // Query stored card details from database
      final response = await SupabaseService.instance.client
          .from('members_card_details')
          .select(
            'id, authorization_code, last4, card_type, brand, exp_month, exp_year',
          )
          .eq('user_id', userId)
          .eq('is_active', true);

      if (response.isEmpty) {
        print('No stored cards found for verification test');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No stored cards found to test')),
        );
        return;
      }

      print('Found ${response.length} stored cards for verification');

      // Test verification for each stored card
      for (final card in response) {
        final authCode = card['authorization_code'] as String?;
        if (authCode != null && authCode.isNotEmpty) {
          print('Testing verification for card ending in ${card['last4']}');
          final paystackService = PaystackService();
          final isValid = await paystackService.testVerifyStoredCard(authCode);
          print('Card verification result for ****${card['last4']}: $isValid');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Card verification test completed - check logs'),
        ),
      );
    } catch (e) {
      print('Error testing card verification: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error testing verification: $e')));
    }
  }
}
