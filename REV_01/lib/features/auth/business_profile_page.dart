import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
// import '../../services/bank_account_service.dart'; // REMOVED: Banking handled by Paystack only

class BusinessProfilePage extends StatefulWidget {
  final String? initialBusinessName;
  final String? initialName;
  final String? initialStreet;
  final String? initialSuburb;
  final String? initialCity;
  final String? initialProvince;
  final String? initialContactEmail;
  final String? initialContactNumber;
  final double? initialLat;
  final double? initialLng;

  const BusinessProfilePage({
    super.key,
    this.initialBusinessName,
    this.initialName,
    this.initialStreet,
    this.initialSuburb,
    this.initialCity,
    this.initialProvince,
    this.initialContactEmail,
    this.initialContactNumber,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _streetController;
  late final TextEditingController _suburbController;
  late final TextEditingController _cityController;
  String? _selectedProvince;
  String? _selectedCategory;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactNumberController;
  double? _selectedLat;
  double? _selectedLng;

  // Bank account fields - REMOVED: Banking details handled by Paystack only
  // late final TextEditingController _accountHolderController;
  // late final TextEditingController _bankNameController;
  // late final TextEditingController _accountNumberController;
  // late final TextEditingController _branchCodeController;
  // String? _selectedAccountType;
  // bool _hasBankAccount = false;

  // final BankAccountService _bankAccountService = BankAccountService();

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
    _nameController = TextEditingController(
      text: widget.initialBusinessName ?? '',
    );
    _streetController = TextEditingController(text: widget.initialStreet ?? '');
    _suburbController = TextEditingController(text: widget.initialSuburb ?? '');
    _cityController = TextEditingController(text: widget.initialCity ?? '');
    _selectedProvince = widget.initialProvince;
    _contactEmailController = TextEditingController(
      text: widget.initialContactEmail ?? '',
    );
    _contactNumberController = TextEditingController(
      text: widget.initialContactNumber ?? '',
    );
    _selectedLat = widget.initialLat;
    _selectedLng = widget.initialLng;

    // Initialize bank account controllers - REMOVED
    // _accountHolderController = TextEditingController();
    // _bankNameController = TextEditingController();
    // _accountNumberController = TextEditingController();
    // _branchCodeController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter business name'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v),
                validator: (v) => v == null ? 'Please select a category' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(labelText: 'Street Address'),
              ),
              TextFormField(
                controller: _suburbController,
                decoration: const InputDecoration(labelText: 'Suburb'),
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactEmailController,
                decoration: const InputDecoration(labelText: 'Contact Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _contactNumberController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              // Bank Account Section - REMOVED: Banking handled by Paystack only
              /*
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Bank Account Setup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: _hasBankAccount,
                          onChanged: (value) {
                            setState(() {
                              _hasBankAccount = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your business bank account to receive payments directly through the app',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (_hasBankAccount) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _accountHolderController,
                        decoration: const InputDecoration(
                          labelText: 'Account Holder Name',
                          hintText: 'Business account holder name',
                        ),
                        validator: _hasBankAccount
                            ? (v) => v == null || v.isEmpty
                                  ? 'Please enter account holder name'
                                  : null
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name',
                          hintText: 'e.g., FNB, Standard Bank, Absa',
                        ),
                        validator: _hasBankAccount
                            ? (v) => v == null || v.isEmpty
                                  ? 'Please enter bank name'
                                  : null
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedAccountType,
                        decoration: const InputDecoration(
                          labelText: 'Account Type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'checking',
                            child: Text('Checking Account'),
                          ),
                          DropdownMenuItem(
                            value: 'savings',
                            child: Text('Savings Account'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedAccountType = value;
                          });
                        },
                        validator: _hasBankAccount
                            ? (v) => v == null || v.isEmpty
                                  ? 'Please select account type'
                                  : null
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _accountNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Account Number',
                          hintText: 'Your business account number',
                        ),
                        keyboardType: TextInputType.number,
                        validator: _hasBankAccount
                            ? (v) => v == null || v.isEmpty
                                  ? 'Please enter account number'
                                  : null
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
                        validator: _hasBankAccount
                            ? (v) {
                                if (v == null || v.isEmpty)
                                  return 'Please enter branch code';
                                if (v.length != 6)
                                  return 'Branch code must be 6 digits';
                                return null;
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
              */
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Business Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'street': _streetController.text.trim(),
      'suburb': _suburbController.text.trim(),
      'city': _cityController.text.trim(),
      'province': _selectedProvince,
      'contact_email': _contactEmailController.text.trim(),
      'contact_number': _contactNumberController.text.trim(),
      'latitude': _selectedLat,
      'longitude': _selectedLng,
    };

    try {
      final res = await SupabaseService.instance.completeBusinessProfile(
        payload,
      );
      if (res is Map && res['ok'] == true) {
        // Business profile saved successfully

        // Save bank account if provided - REMOVED: Banking handled by Paystack only
        /*
        if (_hasBankAccount && _businessId != null) {
          try {
            await _bankAccountService.saveBankAccount(
              businessId: _businessId!,
              accountHolderName: _accountHolderController.text.trim(),
              bankName: _bankNameController.text.trim(),
              accountType: _selectedAccountType!,
              accountNumber: _accountNumberController.text.trim(),
              branchCode: _branchCodeController.text.trim(),
            );
          } catch (e) {
            // Bank account save failed, but business was saved successfully
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Business saved, but bank account setup failed: $e',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
        */

        if (!mounted) return;
        // Use NavigationService to properly route based on user role
        NavigationService().navigateToHomeAfterAuth(context);
      } else {
        final err = res is Map ? res['error'] ?? 'unknown' : res.toString();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Business save failed: $err')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Business save failed: $e')));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _streetController.dispose();
    _suburbController.dispose();
    _cityController.dispose();
    _contactEmailController.dispose();
    _contactNumberController.dispose();
    // Bank account controllers disposed - REMOVED
    // _accountHolderController.dispose();
    // _bankNameController.dispose();
    // _accountNumberController.dispose();
    // _branchCodeController.dispose();
    super.dispose();
  }
}
