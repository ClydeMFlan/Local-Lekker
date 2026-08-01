import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:local_lekker/widgets/branded_app_bar.dart';
import '../../services/supabase_service.dart';
import 'tp_interest_thank_you_page.dart';

class TpInterestFormPage extends StatefulWidget {
  const TpInterestFormPage({super.key});

  @override
  State<TpInterestFormPage> createState() => _TpInterestFormPageState();
}

class _TpInterestFormPageState extends State<TpInterestFormPage> {
  final Logger _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _cityController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();

  String? _selectedBusinessType;
  bool _isSubmitting = false;

  final List<String> _businessTypes = [
    'Restaurant',
    'Café',
    'Bakery',
    'Grocery Store',
    'Butchery',
    'Liquor Store',
    'Clothing Store',
    'Hair Salon / Barber',
    'Beauty & Wellness',
    'Automotive',
    'Hardware Store',
    'Electronics',
    'Pharmacy',
    'Pet Store',
    'Gym / Fitness',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _cityController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final inquiryData = {
        'name': _nameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'city': _cityController.text.trim(),
        'business_name': _businessNameController.text.trim(),
        'business_type': _selectedBusinessType,
        'email': _emailController.text.trim().toLowerCase(),
        'contact_number': _contactController.text.trim(),
      };

      // Store inquiry in Supabase
      await SupabaseService.instance.client
          .from('tp_inquiries')
          .insert(inquiryData);

      _logger.i('TP inquiry submitted successfully');

      // Send email notification to admin via Edge Function
      try {
        await SupabaseService.instance.client.functions.invoke(
          'send-tp-inquiry-email',
          body: inquiryData,
        );
        _logger.i('Admin notification email sent');
      } catch (emailError) {
        // Non-critical - inquiry is already stored in database
        _logger.w('Admin email notification failed: $emailError');
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const TpInterestThankYouPage(),
          ),
        );
      }
    } catch (e) {
      _logger.e('Failed to submit TP inquiry: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to submit your information. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: const Text('Become a Trusted Partner')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Interested in partnering with Local Lekker?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your details below and our team will be in touch to get you set up.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _surnameController,
                decoration: const InputDecoration(labelText: 'Surname'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Surname is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'City is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _businessNameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                textCapitalization: TextCapitalization.words,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Business name is required'
                        : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedBusinessType,
                decoration: const InputDecoration(labelText: 'Business Type'),
                items: _businessTypes
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ))
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedBusinessType = value),
                validator: (value) =>
                    value == null ? 'Please select a business type' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,}$');
                  if (!emailRegex.hasMatch(value.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Contact number is required'
                        : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitInquiry,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
