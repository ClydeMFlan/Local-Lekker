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

  // Track touched fields for red highlight
  final Set<String> _touchedFields = {};

  void _onFieldChanged(String field) {
    setState(() {
      _touchedFields.add(field);
    });
  }

  bool get _allFieldsValid {
    return _nameController.text.isNotEmpty &&
        _surnameController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedGender != null &&
        _selectedEthnicity != null &&
        _streetController.text.isNotEmpty &&
        _suburbController.text.isNotEmpty &&
        _cityController.text.isNotEmpty &&
        _selectedProvince != null &&
        _contactController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _passwordController.text == _confirmPasswordController.text &&
        _passwordController.text.length >= 6 &&
        RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(_emailController.text);
  }

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
                decoration: InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _nameController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _nameController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your name' : null,
                onChanged: (_) => _onFieldChanged('name'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _surnameController,
                decoration: InputDecoration(
                  labelText: 'Surname',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _surnameController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _surnameController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your surname' : null,
                onChanged: (_) => _onFieldChanged('surname'),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _touchedFields.isNotEmpty && _selectedDate == null
                        ? Colors.red
                        : Colors.grey,
                    width: _touchedFields.isNotEmpty && _selectedDate == null
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date of Birth'
                            : 'DOB: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                        style: TextStyle(
                          color:
                              _touchedFields.isNotEmpty && _selectedDate == null
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _onFieldChanged('dob');
                        _selectDate();
                      },
                      child: const Text('Pick Date'),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedGender,
                decoration: InputDecoration(
                  labelText: 'Gender',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty && _selectedGender == null
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty && _selectedGender == null
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                items: _genders.map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (value) {
                  _onFieldChanged('gender');
                  setState(() => _selectedGender = value);
                },
                validator: (value) =>
                    value == null ? 'Please select your gender' : null,
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedEthnicity,
                decoration: InputDecoration(
                  labelText: 'Ethnicity',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _selectedEthnicity == null
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _selectedEthnicity == null
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                items: _ethnicities.map((ethnicity) {
                  return DropdownMenuItem(
                    value: ethnicity,
                    child: Text(ethnicity),
                  );
                }).toList(),
                onChanged: (value) {
                  _onFieldChanged('ethnicity');
                  setState(() => _selectedEthnicity = value);
                },
                validator: (value) =>
                    value == null ? 'Please select your ethnicity' : null,
              ),
              TextFormField(
                controller: _streetController,
                decoration: InputDecoration(
                  labelText: 'Street Address',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _streetController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _streetController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your street address'
                    : null,
                onChanged: (_) => _onFieldChanged('street'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _suburbController,
                decoration: InputDecoration(
                  labelText: 'Suburb',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _suburbController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _suburbController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your suburb' : null,
                onChanged: (_) => _onFieldChanged('suburb'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cityController,
                decoration: InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _cityController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _cityController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your city' : null,
                onChanged: (_) => _onFieldChanged('city'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedProvince,
                decoration: InputDecoration(
                  labelText: 'Province',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty && _selectedProvince == null
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty && _selectedProvince == null
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) {
                  _onFieldChanged('province');
                  setState(() => _selectedProvince = value);
                },
                validator: (value) =>
                    value == null ? 'Please select your province' : null,
              ),
              TextFormField(
                controller: _contactController,
                decoration: InputDecoration(
                  labelText: 'Contact Number',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _contactController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _contactController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your contact number'
                    : null,
                onChanged: (_) => _onFieldChanged('contact'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _emailController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _emailController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
                onChanged: (_) => _onFieldChanged('email'),
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Create Password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _passwordController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _passwordController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter a password';
                  if (value!.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onChanged: (_) => _onFieldChanged('password'),
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(
                    borderSide: BorderSide(
                      color:
                          _touchedFields.isNotEmpty &&
                              _confirmPasswordController.text.isEmpty
                          ? Colors.red
                          : Colors.grey,
                      width:
                          _touchedFields.isNotEmpty &&
                              _confirmPasswordController.text.isEmpty
                          ? 2
                          : 1,
                    ),
                  ),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
                onChanged: (_) => _onFieldChanged('confirmPassword'),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _allFieldsValid ? _createAccount : null,
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaymentScreen()),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String? _selectedPlan;

  final Map<String, Map<String, dynamic>> _plans = {
    'basic': {
      'name': 'Basic Plan',
      'price': 99.00,
      'description': 'Access to basic features',
      'frequency': 1, // months
    },
    'premium': {
      'name': 'Premium Plan',
      'price': 199.00,
      'description': 'Access to all features',
      'frequency': 1, // months
    },
    'annual': {
      'name': 'Annual Plan',
      'price': 999.00,
      'description': 'Yearly subscription with discount',
      'frequency': 12, // months
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Your Plan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Select a subscription plan to continue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ..._plans.entries.map(
                (entry) => _buildPlanCard(entry.key, entry.value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _selectedPlan != null ? _proceedToPayment : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Proceed to Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(String planKey, Map<String, dynamic> plan) {
    final isSelected = _selectedPlan == planKey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedPlan = planKey),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['description'],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'R${plan['price']} / ${plan['frequency'] == 12 ? 'year' : 'month'}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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

  void _proceedToPayment() async {
    if (_selectedPlan == null) return;

    final planDetails = _plans[_selectedPlan]!;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          selectedPlan: _selectedPlan!,
          planDetails: planDetails,
          userId: SupabaseService.instance
              .getCurrentUser()
              ?.id, // Pass current user ID
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
