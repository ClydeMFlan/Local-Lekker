import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import 'widgets/otp_verification_dialog.dart';
import '../payments/payments_feature.dart';

class UserSignupPage extends StatefulWidget {
  const UserSignupPage({super.key});

  @override
  State<UserSignupPage> createState() => _UserSignupPageState();
}

class _UserSignupPageState extends State<UserSignupPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _streetController = TextEditingController();
  final _suburbController = TextEditingController();
  final _cityController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedEthnicity;
  String? _selectedProvince;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Sign Up')),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'Select Date of Birth'
                          : 'DOB: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                    ),
                  ),
                  TextButton(
                    onPressed: _selectDate,
                    child: const Text('Pick Date'),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: _genders.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) => setState(() => _selectedGender = value),
                validator: (value) =>
                    value == null ? 'Please select your gender' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedEthnicity,
                decoration: const InputDecoration(labelText: 'Ethnicity'),
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
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Street Address'),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your street address'
                    : null,
              ),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(labelText: 'Suburb'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your suburb' : null,
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your city' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: const InputDecoration(labelText: 'Province'),
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
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your contact number'
                    : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Create Password'),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ), // 18 years ago
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _createAccount() async {
    if (_formKey.currentState?.validate() ?? false) {
      _logger.i('User signup initiated');
      try {
        final response = await SupabaseService.instance.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          userMetadata: {
            'user_type': 'user',
            'name': _nameController.text,
            'surname': _surnameController.text,
            'street': _streetController.text,
            'suburb': _suburbController.text,
            'city': _cityController.text,
            'province': _selectedProvince,
            'contact': _contactController.text,
            'gender': _selectedGender,
            'ethnicity': _selectedEthnicity,
            'date_of_birth': _selectedDate?.toIso8601String(),
          },
        );
        _logger.i('Signup response: $response');
        if (!mounted) return;
        if (response.user != null) {
          _logger.i('User created successfully: ${response.user!.email}');

          // Show OTP verification dialog instead of proceeding directly to payment
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter the OTP sent to your email'),
                duration: Duration(seconds: 2),
              ),
            );
          }
          _showOtpVerificationDialog();
        } else {
          _logger.w('Signup response user is null');
        }
      } catch (e) {
        _logger.e('Signup error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Signup failed: $e')));
      }
    } else {
      _logger.w('Form validation failed');
    }
  }

  void _showOtpVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (context) => OtpVerificationDialog(
        email: _emailController.text,
        phoneNumber: _contactController.text,
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
              'role': 'user',
              'gender': _selectedGender,
              'ethnicity': _selectedEthnicity,
              'date_of_birth': _selectedDate?.toIso8601String(),
            });
            _logger.i('User profile created successfully');
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

          // Create membership record
          try {
            await SupabaseService.instance.client.from('memberships').insert({
              'user_id': uid,
              'role': 'user',
              'gateway': 'user_signup',
            });
            _logger.i('User membership created successfully');
          } catch (membershipError) {
            _logger.w('Membership creation failed: $membershipError');
          }

          _proceedToPayment();
        },
        userType: 'user', // Specify this is for user signup
      ),
    );
  }

  void _proceedToPayment() {
    // Default to basic plan
    const selectedPlan = 'basic';
    const planDetails = {
      'name': 'Basic Plan',
      'price': 99.00,
      'description': 'Access to basic features',
      'frequency': 1, // months
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          selectedPlan: selectedPlan,
          planDetails: planDetails,
          userId: null, // Will be set after signup
        ),
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Successful')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              'Welcome to Local Lekker!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your subscription has been activated successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                // Navigate to appropriate home screen based on user role
                NavigationService().navigateToHomeAfterAuth(context);
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}
