import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'business_profile_page.dart';
import '../../services/supabase_service.dart';
import 'widgets/otp_verification_dialog.dart';

class TrustedPartnerSignupPage extends StatefulWidget {
  const TrustedPartnerSignupPage({super.key});

  @override
  _TrustedPartnerSignupPageState createState() =>
      _TrustedPartnerSignupPageState();
}

class _TrustedPartnerSignupPageState extends State<TrustedPartnerSignupPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _businessNameController = TextEditingController();
  // business fields moved to a dedicated BusinessProfilePage
  final _streetController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedProvince;
  // business category moved to BusinessProfilePage
  double? _selectedLat;
  double? _selectedLng;
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

  // For additional addresses
  final List<Map<String, TextEditingController>> _additionalAddresses = [];

  void _addAdditionalAddress() {
    setState(() {
      _additionalAddresses.add({
        'street': TextEditingController(),
        'suburb': TextEditingController(),
        'city': TextEditingController(),
        'province': TextEditingController(),
      });
    });
  }

  List<Widget> _buildAdditionalAddressFields() {
    final widgets = <Widget>[];
    for (var i = 0; i < _additionalAddresses.length; i++) {
      final addr = _additionalAddresses[i];
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        Text(
          'Additional Address ${i + 1}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      widgets.add(
        TextFormField(
          controller: addr['street'],
          decoration: const InputDecoration(labelText: 'Street Address'),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter street address' : null,
        ),
      );
      widgets.add(
        TextFormField(
          controller: addr['suburb'],
          decoration: const InputDecoration(labelText: 'Suburb'),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter suburb' : null,
        ),
      );
      widgets.add(
        TextFormField(
          controller: addr['city'],
          decoration: const InputDecoration(labelText: 'City'),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter city' : null,
        ),
      );
      widgets.add(
        TextFormField(
          controller: addr['province'],
          decoration: const InputDecoration(labelText: 'Province'),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Please enter province' : null,
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Partner Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your name' : null,
              ),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Surname'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your surname' : null,
              ),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your business name'
                    : null,
              ),
              // Business fields moved to BusinessProfilePage after OTP
              const SizedBox(height: 12),
              const SizedBox(height: 16),
              const Text(
                'Primary Address (kept minimal)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              // keep minimal address on signup; detailed business address
              // moved to the BusinessProfilePage after OTP
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street Address (optional)',
                ),
              ),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(
                  labelText: 'Suburb (optional)',
                ),
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City (optional)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(
                  labelText: 'Province (optional)',
                ),
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedProvince = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addAdditionalAddress,
                child: const Text('Add Additional Address'),
              ),
              ..._buildAdditionalAddressFields(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter contact number'
                    : null,
              ),
              const SizedBox(height: 8),
              // Optional: simple lat/lng inputs (could be populated by a map picker)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _selectedLat?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Latitude (optional)',
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => _selectedLat = double.tryParse(v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      initialValue: _selectedLng?.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Longitude (optional)',
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (v) => _selectedLng = double.tryParse(v),
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter a password';
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _createAccount,
                child: const Text('Create Account'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _logger.w('Form validation failed');
      return;
    }

    try {
      final response = await SupabaseService.instance.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userMetadata: {
          'user_type': 'trusted_partner',
          'name': _nameController.text,
          'surname': _surnameController.text,
          'street': _streetController.text,
          'suburb': _suburbController.text,
          'city': _cityController.text,
          'province': _selectedProvince,
          'contact': _contactController.text,
        },
      );
      _logger.i('Signup response: $response');

      if (!mounted) return;

      // In both cases (response.user present or null) we show the OTP dialog
      // so the user can confirm their email and we can perform authorization.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter the OTP sent to your email'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (c) => OtpVerificationDialog(
          email: _emailController.text.trim(),
          otpAlreadySent: true,
          isForSignIn: false,
          userType: 'trusted_partner',
          onVerificationSuccess: (String? verifiedUserId) async {
            final uid =
                verifiedUserId ??
                SupabaseService.instance.client.auth.currentUser?.id;

            if (uid == null) {
              _logger.e('Could not determine user id after verification');
              return;
            }

            // Create user profile after successful verification
            try {
              await SupabaseService.instance.client.from('profiles').upsert({
                'id': uid,
                'name': _nameController.text,
                'surname': _surnameController.text,
                'street': _streetController.text,
                'suburb': _suburbController.text,
                'city': _cityController.text,
                'province': _selectedProvince,
                'contact': _contactController.text,
                'email': _emailController.text,
                'role': 'trusted_partner',
              });
              _logger.i('Trusted partner profile created successfully');
            } catch (profileError) {
              _logger.w(
                'Profile creation failed, but signup was successful: $profileError',
              );
              // Show a warning but don't fail the entire signup process
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Account created successfully! Profile details will be available soon.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            }

            // Create trusted partner record
            try {
              await SupabaseService.instance.client
                  .from('trusted_partners')
                  .insert({'user_id': uid, 'business_name': ''});
              _logger.i('Trusted partner record created successfully');
            } catch (partnerError) {
              _logger.w(
                'Trusted partner record creation failed: $partnerError',
              );
            }

            // Create membership record
            try {
              await SupabaseService.instance.client.from('memberships').insert({
                'user_id': uid,
                'role': 'trusted_partner',
                'gateway': 'trusted_partner_signup',
              });
              _logger.i('Membership record created successfully');
            } catch (membershipError) {
              _logger.w('Membership record creation failed: $membershipError');
            }

            // After OTP verification we navigate to the business profile
            // page so the user can complete the business details.
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (ctx) => BusinessProfilePage(
                  initialBusinessName: _businessNameController.text.trim(),
                  initialName: _nameController.text.trim(),
                  initialStreet: _streetController.text.trim(),
                  initialSuburb: _suburbController.text.trim(),
                  initialCity: _cityController.text.trim(),
                  initialProvince: _selectedProvince,
                  initialContactEmail: _emailController.text.trim(),
                  initialContactNumber: _contactController.text.trim(),
                  initialLat: _selectedLat,
                  initialLng: _selectedLng,
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      _logger.e('Signup error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Signup failed: $e')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _businessNameController.dispose();
    _streetController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    for (var address in _additionalAddresses) {
      for (var controller in address.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }
}
