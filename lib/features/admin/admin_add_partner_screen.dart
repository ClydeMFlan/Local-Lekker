import 'package:flutter/material.dart';
import 'package:local_lekker/widgets/branded_app_bar.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import 'package:local_lekker/core/theme/app_colors.dart';

/// Screen for admins to create a new Trusted Partner account.
class AdminAddPartnerScreen extends StatefulWidget {
  const AdminAddPartnerScreen({super.key});

  @override
  State<AdminAddPartnerScreen> createState() => _AdminAddPartnerScreenState();
}

class _AdminAddPartnerScreenState extends State<AdminAddPartnerScreen> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  String _selectedCategory = 'Restaurant';
  String? _selectedProvince;
  String? _selectedCity;
  bool _obscurePassword = true;
  bool _isSubmitting = false;

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
    'Other',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _businessNameCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final metadata = {
        'name': _nameCtrl.text.trim(),
        'surname': _surnameCtrl.text.trim(),
        'business_name': _businessNameCtrl.text.trim(),
        'category': _selectedCategory,
        'contact': _contactCtrl.text.trim(),
        'city': _selectedCity ?? '',
        'role': 'trusted_partner',
        'user_type': 'trusted_partner',
        'admin_created': true,
        'password_set': true,
      };

      final result = await SupabaseService.instance.adminCreateTrustedPartner(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        metadata: metadata,
      );

      _logger.i('Create TP result: $result');

      if (!mounted) return;

      final ok = result['ok'] == true;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trusted Partner created successfully'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context, true); // Return true to trigger refresh
      } else {
        final error = result['error']?.toString() ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error creating TP: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(
        title: const Text('Add Trusted Partner'),
        centerTitle: false,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Account Section ──
              _SectionHeader(title: 'Account Details'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration('Email', Icons.email_outlined),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: _inputDecoration('Password', Icons.lock_outlined).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // ── Owner Section ──
              _SectionHeader(title: 'Owner Information'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('First Name', Icons.person_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _surnameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration('Surname', Icons.person_outlined),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactCtrl,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration('Contact Number', Icons.phone_outlined),
              ),

              const SizedBox(height: 24),

              // ── Business Section ──
              _SectionHeader(title: 'Business Information'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _businessNameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDecoration('Business Name', Icons.store_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Business name is required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration('Category', Icons.category_outlined),
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
                decoration: _inputDecoration('Province', Icons.map_outlined),
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
                decoration: _inputDecoration('City', Icons.location_city_outlined),
                items: (_selectedProvince != null
                        ? _citiesByProvince[_selectedProvince!] ?? <String>[]
                        : <String>[])
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCity = v),
                validator: (v) => v == null ? 'Please select a city' : null,
              ),

              const SizedBox(height: 32),

              // ── Submit ──
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_isSubmitting ? 'Creating...' : 'Create Trusted Partner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
