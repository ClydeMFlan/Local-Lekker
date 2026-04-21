import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:logger/logger.dart';
import 'dart:async';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import 'widgets/otp_verification_dialog.dart';
import 'widgets/address_autocomplete_field.dart';
import 'welcome_page.dart';

class MembersSignupPage extends StatefulWidget {
  const MembersSignupPage({super.key});

  @override
  State<MembersSignupPage> createState() => _MembersSignupPageState();
}

class _MembersSignupPageState extends State<MembersSignupPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _streetController = TextEditingController();
  final _suburbController = TextEditingController();
  String? _selectedCity;
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedGender;
  String? _selectedEthnicity;
  String? _selectedProvince;

  // Flag to trigger navigation to payment screen
  bool _shouldNavigateToPayment = false;

  // Email check state
  Timer? _emailDebounce;
  bool _checkingEmail = false;
  bool _emailIsActive = false;
  bool _emailIsDeactivated = false;

  // Store reference to ScaffoldMessenger to avoid context issues
  late ScaffoldMessengerState _scaffoldMessenger;

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

  final Map<String, List<String>> _citiesByProvince = {
    'Eastern Cape': [
      'Bhisho',
      'Butterworth',
      'Cradock',
      'East London',
      'Graaff-Reinet',
      'Grahamstown (Makhanda)',
      'Jeffreys Bay',
      'King William\'s Town',
      'Mthatha',
      'Port Elizabeth (Gqeberha)',
      'Queenstown',
      'Uitenhage',
    ],
    'Free State': [
      'Bethlehem',
      'Bloemfontein',
      'Kroonstad',
      'Parys',
      'Phuthaditjhaba',
      'Sasolburg',
      'Virginia',
      'Welkom',
    ],
    'Gauteng': [
      'Alberton',
      'Benoni',
      'Boksburg',
      'Brakpan',
      'Carletonville',
      'Centurion',
      'Germiston',
      'Johannesburg',
      'Krugersdorp',
      'Midrand',
      'Pretoria',
      'Randburg',
      'Roodepoort',
      'Sandton',
      'Soweto',
      'Springs',
      'Vanderbijlpark',
      'Vereeniging',
    ],
    'KwaZulu-Natal': [
      'Ballito',
      'Durban',
      'Empangeni',
      'Eshowe',
      'Ladysmith',
      'Margate',
      'Newcastle',
      'Pietermaritzburg',
      'Pinetown',
      'Port Shepstone',
      'Richards Bay',
      'Ulundi',
      'Umhlanga',
    ],
    'Limpopo': [
      'Bela-Bela',
      'Giyani',
      'Lephalale',
      'Louis Trichardt (Makhado)',
      'Mokopane',
      'Musina',
      'Phalaborwa',
      'Polokwane',
      'Thohoyandou',
      'Tzaneen',
    ],
    'Mpumalanga': [
      'Barberton',
      'Bethal',
      'Ermelo',
      'Middelburg',
      'Nelspruit (Mbombela)',
      'Secunda',
      'Standerton',
      'Witbank (Emalahleni)',
    ],
    'Northern Cape': [
      'De Aar',
      'Kathu',
      'Kimberley',
      'Kuruman',
      'Springbok',
      'Upington',
    ],
    'North West': [
      'Brits',
      'Klerksdorp',
      'Lichtenburg',
      'Mahikeng',
      'Potchefstroom',
      'Rustenburg',
    ],
    'Western Cape': [
      'Beaufort West',
      'Cape Town',
      'George',
      'Hermanus',
      'Knysna',
      'Mossel Bay',
      'Oudtshoorn',
      'Paarl',
      'Saldanha',
      'Somerset West',
      'Stellenbosch',
      'Swellendam',
      'Worcester',
    ],
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store reference to ScaffoldMessenger to avoid context issues in callbacks
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _nameController.dispose();
    _surnameController.dispose();
    _streetController.dispose();
    _suburbController.dispose();

    _contactController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle navigation to payment screen after OTP verification
    if (_shouldNavigateToPayment) {
      _shouldNavigateToPayment = false; // Reset flag
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _proceedToPayment();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Member Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: _emailIsDeactivated
                      ? 'We found your deactivated account and prefilled your details.'
                      : _emailIsActive
                      ? 'Existing active account detected. Redirecting to sign in.'
                      : null,
                  suffixIcon: _checkingEmail
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : _emailIsActive
                      ? const Icon(Icons.login, color: Colors.green)
                      : _emailIsDeactivated
                      ? const Icon(Icons.restart_alt, color: Colors.orange)
                      : null,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: _onEmailChanged,
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Please enter your email';
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                    return 'Please enter a valid email';
                  }
                  if (_emailIsActive) {
                    return 'This email already has an active account. Please sign in instead.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
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
              const Divider(height: 32),
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
                          : 'DOB: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    ),
                  ),
                  TextButton(
                    onPressed: _showDatePicker,
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
              AddressAutocompleteField(
                controller: _streetController,
                labelText: 'Street Address',
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your street address'
                    : null,
                onAddressSelected: _parseAddress,
              ),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(labelText: 'Suburb'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Please enter your suburb' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedProvince,
                decoration: const InputDecoration(labelText: 'Province'),
                items: _provinces.map((province) {
                  return DropdownMenuItem(
                    value: province,
                    child: Text(province),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedProvince = value;
                    _selectedCity = null;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select your province' : null,
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedProvince),
                value: _selectedCity,
                decoration: const InputDecoration(labelText: 'City'),
                items: (_selectedProvince != null
                        ? _citiesByProvince[_selectedProvince!] ?? []
                        : <String>[])
                    .map((city) {
                  return DropdownMenuItem(
                    value: city,
                    child: Text(city),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCity = value),
                validator: (value) =>
                    value == null ? 'Please select your city' : null,
              ),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true
                    ? 'Please enter your contact number'
                    : null,
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

  void _onEmailChanged(String value) {
    _emailDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _checkingEmail = false;
        _emailIsActive = false;
        _emailIsDeactivated = false;
      });
      return;
    }

    _emailDebounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _checkingEmail = true;
        _emailIsActive = false;
        _emailIsDeactivated = false;
      });

      // Check if there's a profile (active or deactivated)
      final profile = await SupabaseService.instance.getProfileByEmail(trimmed);
      if (!mounted) return;

      if (profile != null) {
        final isDeactivated = profile['is_deactivated'] == true;

        if (!isDeactivated) {
          // Active account - redirect to sign in
          setState(() {
            _checkingEmail = false;
            _emailIsActive = true;
          });
          await _redirectToSignIn(trimmed);
          return;
        }

        // Deactivated account - autofill from profile
        _logger.i('Found deactivated member for email: $trimmed. Autofilling.');
        _prefillFromProfile(profile);
        setState(() {
          _checkingEmail = false;
          _emailIsDeactivated = true;
        });

        // Show welcome back message for deactivated members
        _scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Welcome back! We found your previous details and autofilled the form.',
            ),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      // No profile found - new member
      setState(() {
        _checkingEmail = false;
        _emailIsActive = false;
        _emailIsDeactivated = false;
      });
    });
  }

  void _prefillFromProfile(Map<String, dynamic> profile) {
    _nameController.text = (profile['name'] ?? '') as String;
    _surnameController.text = (profile['surname'] ?? '') as String;
    _streetController.text = (profile['street'] ?? '') as String;
    _suburbController.text = (profile['suburb'] ?? '') as String;
    _contactController.text = (profile['contact'] ?? '') as String;
    _selectedProvince = profile['province'] as String?;
    final profileCity = profile['city'] as String?;
    if (_selectedProvince != null && profileCity != null) {
      final cities = _citiesByProvince[_selectedProvince!] ?? [];
      _selectedCity = cities.contains(profileCity) ? profileCity : null;
    }
    _selectedGender = profile['gender'] as String?;
    _selectedEthnicity = profile['ethnicity'] as String?;

    final dob = profile['date_of_birth'] as String?;
    if (dob != null) {
      _selectedDate = DateTime.tryParse(dob);
    }

    // Keep email controller as-is (user input), but ensure trimmed casing
    if (profile['email'] is String) {
      _emailController.text = (profile['email'] as String).trim();
    }
  }

  Future<void> _redirectToSignIn(String email) async {
    _scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text(
          'This email already has an active account. Redirecting to sign in.',
        ),
        duration: Duration(seconds: 3),
      ),
    );

    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WelcomePage(openSignInOnLoad: true, prefillEmail: email.trim()),
      ),
      (route) => false,
    );
  }

  Future<void> _showDatePicker() async {
    final DateTime now = DateTime.now();
    int selectedDay = _selectedDate?.day ?? (now.day - 1);
    int selectedMonth = _selectedDate?.month ?? now.month;
    int selectedYear = _selectedDate?.year ?? (now.year - 18);

    // Ensure selectedDay is valid for the selected month/year
    int maxDays = _getDaysInMonth(selectedYear, selectedMonth);
    if (selectedDay > maxDays) {
      selectedDay = maxDays;
    }

    await showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SizedBox(
              height: 300,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const Text(
                          'Select Date of Birth',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final selectedDate = DateTime(
                              selectedYear,
                              selectedMonth,
                              selectedDay,
                            );
                            this.setState(() => _selectedDate = selectedDate);
                            Navigator.pop(context);
                          },
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        // Day picker
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedDay - 1,
                            ),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                selectedDay = index + 1;
                              });
                            },
                            children: List<Widget>.generate(
                              _getDaysInMonth(selectedYear, selectedMonth),
                              (int index) {
                                return Center(child: Text('${index + 1}'));
                              },
                            ),
                          ),
                        ),
                        // Month picker
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedMonth - 1,
                            ),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                selectedMonth = index + 1;
                                // Adjust day if necessary when month changes
                                int maxDays = _getDaysInMonth(
                                  selectedYear,
                                  selectedMonth,
                                );
                                if (selectedDay > maxDays) {
                                  selectedDay = maxDays;
                                }
                              });
                            },
                            children: List<Widget>.generate(12, (int index) {
                              final monthNames = [
                                'Jan',
                                'Feb',
                                'Mar',
                                'Apr',
                                'May',
                                'Jun',
                                'Jul',
                                'Aug',
                                'Sep',
                                'Oct',
                                'Nov',
                                'Dec',
                              ];
                              return Center(child: Text(monthNames[index]));
                            }),
                          ),
                        ),
                        // Year picker
                        Expanded(
                          child: CupertinoPicker(
                            itemExtent: 40,
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedYear - 1900,
                            ),
                            onSelectedItemChanged: (int index) {
                              setState(() {
                                selectedYear = 1900 + index;
                                // Adjust day if necessary when year changes (leap year)
                                int maxDays = _getDaysInMonth(
                                  selectedYear,
                                  selectedMonth,
                                );
                                if (selectedDay > maxDays) {
                                  selectedDay = maxDays;
                                }
                              });
                            },
                            children: List<Widget>.generate(125, (int index) {
                              return Center(child: Text('${1900 + index}'));
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _parseAddress(String address) {
    // Simple parsing logic to extract components from Google Places address
    // This is a basic implementation - you might want to use Google Places Details API for more accurate parsing
    final parts = address.split(', ');

    if (parts.length >= 3) {
      // Assume format: "Street Address, Suburb, City, Province, Country"
      _streetController.text = parts[0];

      if (parts.length >= 2) {
        _suburbController.text = parts[1];
      }

      // Try to extract province from the address
      String? detectedProvince;
      for (final province in _provinces) {
        if (address.toLowerCase().contains(province.toLowerCase())) {
          detectedProvince = province;
          break;
        }
      }

      if (detectedProvince != null) {
        setState(() {
          _selectedProvince = detectedProvince;
          _selectedCity = null;
          // Try to match city from parsed address to dropdown options
          if (parts.length >= 3) {
            final parsedCity = parts[2].trim();
            final cities = _citiesByProvince[detectedProvince!] ?? [];
            for (final city in cities) {
              if (city.toLowerCase() == parsedCity.toLowerCase() ||
                  city.toLowerCase().contains(parsedCity.toLowerCase()) ||
                  parsedCity.toLowerCase().contains(city.toLowerCase())) {
                _selectedCity = city;
                break;
              }
            }
          }
        });
      }
    }
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      // February - check for leap year
      if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) {
        return 29;
      } else {
        return 28;
      }
    } else if ([4, 6, 9, 11].contains(month)) {
      return 30;
    } else {
      return 31;
    }
  }

  void _createAccount() async {
    if (_emailIsActive) {
      await _redirectToSignIn(_emailController.text);
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      _logger.i('User signup initiated - showing OTP method selection');
      // Do NOT call signUpWithOtp here. Let the user choose their OTP
      // delivery method and click "Send OTP" in the dialog first.
      _showOtpVerificationDialog();
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
        userMetadata: {
          'user_type': 'member',
          'name': _nameController.text,
          'surname': _surnameController.text,
          'street': _streetController.text,
          'suburb': _suburbController.text,
          'city': _selectedCity,
          'province': _selectedProvince,
          'contact': _contactController.text,
          'gender': _selectedGender,
          'ethnicity': _selectedEthnicity,
          'date_of_birth': _selectedDate?.toIso8601String(),
          'temp_password': _passwordController.text,
        },
        onVerificationSuccess: (String? verifiedUserId) async {
          _logger.i('OTP verification successful, userId: $verifiedUserId');

          final uid =
              verifiedUserId ??
              SupabaseService.instance.client.auth.currentUser?.id;

          _logger.i('Final user ID for profile creation: $uid');
          _logger.i(
            'Current user from Supabase: ${SupabaseService.instance.client.auth.currentUser}',
          );
          _logger.i(
            'Current user metadata: ${SupabaseService.instance.client.auth.currentUser?.userMetadata}',
          );

          if (uid == null) {
            _logger.e('Could not determine user id after verification');
            return;
          }

          // Set the password after OTP verification
          try {
            final tempPassword =
                SupabaseService
                        .instance
                        .client
                        .auth
                        .currentUser
                        ?.userMetadata?['temp_password']
                    as String?;

            if (tempPassword != null && tempPassword.isNotEmpty) {
              await SupabaseService.instance.updatePassword(
                newPassword: tempPassword,
              );
              _logger.i('Password set successfully after OTP verification');
            } else {
              _logger.w(
                'No temp_password found in metadata, using default or skipping password set',
              );
            }
          } catch (passwordError) {
            _logger.e('Failed to set password after OTP: $passwordError');
            // Continue anyway - user can reset password later if needed
          }

          // Create user profile after successful verification
          try {
            await SupabaseService.instance.createUserProfile(
              userId: uid,
              userData: {
                'name': _nameController.text,
                'surname': _surnameController.text,
                'street': _streetController.text,
                'suburb': _suburbController.text,
                'city': _selectedCity,
                'province': _selectedProvince,
                'contact': _contactController.text,
                'email': _emailController.text,
                'gender': _selectedGender,
                'ethnicity': _selectedEthnicity,
                'date_of_birth': _selectedDate?.toIso8601String(),
              },
            );
            _logger.i('User profile created successfully');

            // Membership record is now created by the createUserProfile function

            _logger.i('About to trigger payment navigation');

            // Set flag to trigger navigation to payment in build method
            setState(() {
              _shouldNavigateToPayment = true;
            });
          } catch (profileError) {
            _logger.e('Profile creation failed: $profileError');
            // Profile creation is critical for sign-in to work later
            if (mounted) {
              _scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Account verification failed. Please try again.',
                  ),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            // Don't proceed to payment if profile creation failed
            return;
          }
        },
        userType: 'member', // Specify this is for member signup
      ),
    );
  }

  void _proceedToPayment() {
    _logger.i(
      'Proceeding to terms acceptance and payment flow after OTP verification',
    );

    final userId = SupabaseService.instance.client.auth.currentUser?.id;
    _logger.i('Current user ID: $userId');

    // Use a very short delay to ensure dialog is fully closed
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        _logger.e(
          'MembersSignupPage context is not mounted after delay, cannot navigate',
        );
        return;
      }

      _logger.i(
        'Context is still mounted after delay, proceeding with navigation',
      );

      // CRITICAL: Use centralized navigation to enforce terms acceptance before payment
      // This ensures member must accept terms & conditions before reaching payment screen
      NavigationService().navigateToHomeAfterAuth(context);
    });
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
