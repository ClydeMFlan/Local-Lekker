import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../services/supabase_service.dart';
import '../../services/navigation_service.dart';
import '../../services/paystack_service.dart';
import 'change_password_page.dart';

class BusinessProfilePage extends StatefulWidget {
  final String? initialBusinessName;
  final String? initialName;
  final String? initialAddress;
  final String? initialContactEmail;
  final String? initialContactNumber;
  final String? initialCategory;
  final bool requireCompletion; // New flag for first-time setup
  // Latitude/longitude removed - not needed

  const BusinessProfilePage({
    super.key,
    this.initialBusinessName,
    this.initialName,
    this.initialAddress,
    this.initialContactEmail,
    this.initialContactNumber,
    this.initialCategory,
    this.requireCompletion =
        false, // Default to false for backward compatibility
    // Lat/lng parameters removed
  });

  @override
  State<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends State<BusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactEmailController;
  late final TextEditingController _contactNumberController;
  // Latitude/longitude removed - not needed
  // Note: businessId no longer required for bank accounts; logos may still use returned id
  String? _selectedCategory;
  bool _isLoading = true; // Add loading state
  String? _trustedPartnerKey;

  // Paystack subaccount setup fields
  late final TextEditingController _accountHolderController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  bool _hasPaystackSubaccount = false;

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
    _addressController = TextEditingController(
      text: widget.initialAddress ?? '',
    );
    _contactEmailController = TextEditingController(
      text: widget.initialContactEmail ?? '',
    );
    _contactNumberController = TextEditingController(
      text: widget.initialContactNumber ?? '',
    );
    // Lat/lng initialization removed
    _selectedCategory = widget.initialCategory;

    // Initialize Paystack subaccount controllers
    _accountHolderController = TextEditingController();
    _bankNameController = TextEditingController();
    _accountNumberController = TextEditingController();

    // Load existing data if no initial values provided
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    // Only load if no initial values were provided (not during signup)
    if (widget.initialBusinessName == null &&
        widget.initialName == null &&
        widget.initialAddress == null) {
      try {
        final user = SupabaseService.instance.getCurrentUser();
        if (user != null) {
          // Load business data with timeout
          final businessResponse = await SupabaseService.instance.client
              .from('businesses')
              .select('name, address, contact_email, contact_number, category')
              .eq('owner_member_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Load profile data with timeout
          final profileResponse = await SupabaseService.instance.client
              .from('profiles')
              .select(
                'name, surname, email, contact, street, suburb, city, province',
              )
              .eq('id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Load trusted partner key and banking details status
          final tpResponse = await SupabaseService.instance.client
              .from('trusted_partners')
              .select('unique_key, paystack_subaccount_id')
              .eq('user_id', user.id)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          // Check for banking details in trusted_partner_bank_accounts
          final bankingResponse = await SupabaseService.instance.client
              .from('trusted_partner_bank_accounts')
              .select('paystack_recipient_code')
              .eq('user_id', user.id)
              .eq('is_active', true)
              .maybeSingle()
              .timeout(const Duration(seconds: 10));

          if (mounted) {
            setState(() {
              // Update controllers with loaded data
              if (businessResponse != null) {
                _nameController.text = businessResponse['name'] ?? '';
                _addressController.text = businessResponse['address'] ?? '';
                _selectedCategory = businessResponse['category'];
                _contactEmailController.text =
                    businessResponse['contact_email'] ?? '';
                _contactNumberController.text =
                    businessResponse['contact_number'] ?? '';
                // Lat/lng loading removed
              }

              // Store trusted partner key and banking details status
              if (tpResponse != null) {
                _trustedPartnerKey = tpResponse['unique_key'];
              }

              // Check if banking details exist
              _hasPaystackSubaccount =
                  (tpResponse != null &&
                      tpResponse['paystack_subaccount_id'] != null) ||
                  (bankingResponse != null &&
                      bankingResponse['paystack_recipient_code'] != null);

              // Use profile address if business address is null
              if (profileResponse != null &&
                  (businessResponse?['address'] == null ||
                      businessResponse?['address'] == '')) {
                final profileAddressParts =
                    [
                          profileResponse['street'],
                          profileResponse['suburb'],
                          profileResponse['city'],
                          profileResponse['province'],
                        ]
                        .where(
                          (part) => part != null && part.toString().isNotEmpty,
                        )
                        .toList();
                final profileAddress = profileAddressParts.join(', ');
                if (profileAddress.isNotEmpty) {
                  _addressController.text = profileAddress;
                }
              }

              // Use profile data as fallback for contact info
              if (profileResponse != null &&
                  businessResponse?['contact_email'] == null) {
                _contactEmailController.text = profileResponse['email'] ?? '';
              }
              if (profileResponse != null &&
                  businessResponse?['contact_number'] == null) {
                _contactNumberController.text =
                    profileResponse['contact'] ?? '';
              }
            });
          }
        }
      } catch (e) {
        Logger().e('Error loading existing business data: $e');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load business data: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // During signup, no need to load existing data
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.requireCompletion
              ? 'Complete Your Profile'
              : 'Business Details',
        ),
        automaticallyImplyLeading:
            !widget.requireCompletion, // Prevent back if required
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Show info banner if profile completion is required
              if (widget.requireCompletion)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please complete your business profile to continue. All fields are required.',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v == null || v.isEmpty
                    ? 'Please enter business name'
                    : null,
              ),
              const SizedBox(height: 12),
              // Trusted Partner Key Display
              if (_trustedPartnerKey != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.vpn_key, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Your Trusted Partner Key',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _trustedPartnerKey!,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _trustedPartnerKey!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Key copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            tooltip: 'Copy key',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Share this key with members to give them free access',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              if (_trustedPartnerKey != null) const SizedBox(height: 12),
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
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 3,
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
              // Paystack Subaccount Setup Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.blue),
                        const SizedBox(width: 8),
                        const Text(
                          'Banking Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect your bank account to receive payments from members. Click below to securely upload your banking details through Paystack.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    // Always show the button for editing banking details
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showBankingDetailsForm,
                          icon: const Icon(Icons.account_balance),
                          label: Text(
                            _hasPaystackSubaccount
                                ? 'Edit Banking Details'
                                : 'Upload Banking Details',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasPaystackSubaccount
                              ? 'Update your banking details for receiving payments from members'
                              : 'Click to securely enter your banking details for receiving payments',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                        if (_hasPaystackSubaccount) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Banking details configured',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Security Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lock_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Security',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Manage your account password. You will verify with a one-time code before changing it.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
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
                      ),
                    ),
                  ],
                ),
              ),
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

    // If this is first-time setup, validate that all required fields are completed
    if (widget.requireCompletion) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your business name'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a business category'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_addressController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your business address'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_contactEmailController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your contact email'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      if (_contactNumberController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your contact number'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // Banking details are optional but recommended
      if (!_hasPaystackSubaccount) {
        // Show confirmation dialog
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Banking Details'),
            content: const Text(
              'You haven\'t set up your banking details yet. You won\'t be able to receive payments from members until you add them.\n\nDo you want to continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Go Back'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }

    final payload = {
      'name': _nameController.text.trim(),
      'category': _selectedCategory,
      'address': _addressController.text.trim(),
      'contact_email': _contactEmailController.text.trim(),
      'contact_number': _contactNumberController.text.trim(),
      // Lat/lng removed from payload
    };

    try {
      final res = await SupabaseService.instance.completeBusinessProfile(
        payload,
      );
      if (res is Map && res['ok'] == true) {
        // Business ID is returned and can be used for logos if needed: res['business_id']

        if (!mounted) return;

        // Show success message for first-time setup
        if (widget.requireCompletion) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile completed! Redirecting to home...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
        }

        // Use NavigationService to properly route based on user role
        if (mounted) {
          NavigationService().navigateToHomeAfterAuth(context);
        }
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

  Future<void> _showBankingDetailsForm() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => BankingDetailsDialog(
        businessName: _nameController.text.trim(),
        hasExistingDetails: _hasPaystackSubaccount,
      ),
    );

    if (result == true && mounted) {
      // Banking details were successfully saved
      setState(() {
        _hasPaystackSubaccount = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Banking details saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactEmailController.dispose();
    _contactNumberController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }
}

class BankingDetailsDialog extends StatefulWidget {
  final String businessName;
  final bool hasExistingDetails;

  const BankingDetailsDialog({
    super.key,
    required this.businessName,
    this.hasExistingDetails = false,
  });

  @override
  State<BankingDetailsDialog> createState() => _BankingDetailsDialogState();
}

class _BankingDetailsDialogState extends State<BankingDetailsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchCodeController = TextEditingController();
  String? _selectedAccountType;
  String? _selectedBankCode;
  bool _isLoading = false;

  final List<String> _accountTypes = ['savings', 'checking'];
  final List<String> _banks = [
    'Absa Bank',
    'Capitec Bank',
    'FNB',
    'Nedbank',
    'Standard Bank',
    'Investec',
    'African Bank',
    'Discovery Bank',
    'Other',
  ];

  final Map<String, String> _bankCodes = {
    'Absa Bank': '632005',
    'Capitec Bank': '470010',
    'FNB': '250655',
    'Nedbank': '198765',
    'Standard Bank': '051001',
    'Investec': '580105',
    'African Bank': '430000',
    'Discovery Bank': '679000',
  };

  @override
  void initState() {
    super.initState();
    _accountNameController.text = widget.businessName;
    if (widget.hasExistingDetails) {
      _loadExistingBankingDetails();
    }
  }

  Future<void> _loadExistingBankingDetails() async {
    print(
      '🔄 DEBUG BankingDetailsDialog: Starting _loadExistingBankingDetails',
    );
    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) {
        print('❌ DEBUG BankingDetailsDialog: No authenticated user');
        return;
      }
      print('👤 DEBUG BankingDetailsDialog: Authenticated user: ${user.id}');

      // Get banking details for the user (not tied to a specific business)
      // Banking details are user-level, not business-level
      final paystackService = PaystackService();
      print(
        '🏦 DEBUG BankingDetailsDialog: Calling paystackService.getBankingDetailsForUser',
      );

      final bankingDetails = await paystackService.getBankingDetailsForUser(
        user.id,
      );

      print(
        '📋 DEBUG BankingDetailsDialog: Banking details result: $bankingDetails',
      );

      if (bankingDetails != null && mounted) {
        print(
          '✅ DEBUG BankingDetailsDialog: Populating form with banking details',
        );
        setState(() {
          _accountNameController.text =
              bankingDetails['account_name'] ?? widget.businessName;
          _accountNumberController.text =
              bankingDetails['account_number'] ?? '';
          // Map the bank name from Paystack to our dropdown values
          final mappedBankName = _mapBankNameToDropdown(
            bankingDetails['bank_name'] ?? '',
          );
          _bankNameController.text = mappedBankName;
          _selectedAccountType = bankingDetails['account_type'] ?? 'savings';
          // Load branch code from database (stored separately from Paystack)
          _branchCodeController.text = bankingDetails['branch_code'] ?? '';
        });
        print('📝 DEBUG BankingDetailsDialog: Form populated successfully');
      } else {
        print(
          '❌ DEBUG BankingDetailsDialog: No banking details found or component not mounted',
        );
      }
    } catch (e) {
      print('💥 DEBUG BankingDetailsDialog: Error loading banking details: $e');
      // If loading fails, just continue with empty form
      // User can still enter details manually
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.hasExistingDetails
            ? 'Update Banking Details'
            : 'Enter Banking Details',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please enter your banking details for receiving payments from members.',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              const SizedBox(height: 16),
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
                initialValue:
                    _bankNameController.text.isEmpty ||
                        !_banks.contains(_bankNameController.text)
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
                    _selectedBankCode = _bankCodes[value ?? 'Other'];
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
                  hintText:
                      'Your business account number (will be masked for security)',
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
                  if (v == null || v.isEmpty) return 'Please enter branch code';
                  if (v.length != 6) return 'Branch code must be 6 digits';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveBankingDetails,
          child: _isLoading
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
    print('🔄 DEBUG BankingDetailsDialog: Starting _saveBankingDetails');
    if (!(_formKey.currentState?.validate() ?? false)) {
      print('❌ DEBUG BankingDetailsDialog: Form validation failed');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = SupabaseService.instance.getCurrentUser();
      if (user == null) throw Exception('No authenticated user');
      print('👤 DEBUG BankingDetailsDialog: Authenticated user: ${user.id}');

      // Get business ID from businesses table
      final businessResponse = await SupabaseService.instance.client
          .from('businesses')
          .select('id')
          .eq('owner_member_id', user.id)
          .maybeSingle();

      if (businessResponse == null || businessResponse['id'] == null) {
        throw Exception(
          'Business not found. Please complete business setup first.',
        );
      }

      final businessId = businessResponse['id'].toString();
      print('🏢 DEBUG BankingDetailsDialog: Found business ID: $businessId');

      // Get bank code from selected bank
      final bankCode =
          _selectedBankCode ?? _bankCodes[_bankNameController.text] ?? '';
      print(
        '🏦 DEBUG BankingDetailsDialog: Bank name: ${_bankNameController.text}, Bank code: $bankCode',
      );

      // Create or update transfer recipient with banking details
      final paystackService = PaystackService();

      // If we have existing details, we need to delete the old recipient first
      // since Paystack doesn't support updating transfer recipients
      if (widget.hasExistingDetails) {
        print(
          '🔄 DEBUG BankingDetailsDialog: Has existing details, checking for old recipient',
        );
        final existingDetails = await paystackService.getBankingDetailsForUser(
          businessId,
        );
        if (existingDetails != null &&
            existingDetails['recipient_code'] != null) {
          print(
            '📋 DEBUG BankingDetailsDialog: Found existing recipient code: ${existingDetails['recipient_code']}',
          );
          // Delete the old recipient from Paystack
          final deleteSuccess = await paystackService.deleteTransferRecipient(
            existingDetails['recipient_code'],
          );
          if (deleteSuccess) {
            print(
              '✅ DEBUG BankingDetailsDialog: Successfully deleted old recipient: ${existingDetails['recipient_code']}',
            );
          } else {
            print(
              '⚠️ DEBUG BankingDetailsDialog: Failed to delete old recipient: ${existingDetails['recipient_code']}',
            );
            // Continue anyway - we'll create a new recipient
          }
        }
      }

      print('📤 DEBUG BankingDetailsDialog: Creating transfer recipient...');
      print('📊 DEBUG BankingDetailsDialog: Payload data:');
      print('   - businessId: $businessId');
      print('   - businessName: ${widget.businessName}');
      print('   - bankCode: $bankCode');
      print('   - accountNumber: ${_accountNumberController.text.trim()}');
      print('   - accountName: ${_accountNameController.text.trim()}');

      final recipientCode = await paystackService.createTransferRecipient(
        businessId: businessId,
        businessName: widget.businessName,
        bankCode: bankCode,
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        accountType:
            _selectedAccountType ?? 'savings', // Pass the selected account type
      );

      print(
        '✅ DEBUG BankingDetailsDialog: Transfer recipient created: $recipientCode',
      );

      if (recipientCode != null) {
        print(
          '💾 DEBUG BankingDetailsDialog: Banking details saved successfully',
        );
        print('🔑 DEBUG BankingDetailsDialog: Recipient code: $recipientCode');

        // Save/update complete banking details to trusted_partner_bank_accounts table
        // Mask account number for security - only store last 4 digits
        final maskedAccountNumber = _maskAccountNumber(
          _accountNumberController.text.trim(),
        );

        // Create Paystack subaccount for split payments
        String? subaccountCode;
        String? verificationMessage;
        try {
          print(
            '💳 DEBUG BankingDetailsDialog: Creating Paystack subaccount with verification...',
          );
          print(
            '🏦 Verifying bank account: ${_accountNumberController.text.trim()} with bank code: $bankCode',
          );

          subaccountCode = await paystackService.createSubaccount(
            businessName: widget.businessName,
            bankCode: bankCode,
            accountNumber: _accountNumberController.text.trim(),
            businessId: businessId,
            percentageCharge: 90.0, // Partner gets 90%, platform gets 10%
          );

          print(
            '✅ DEBUG BankingDetailsDialog: Subaccount created: $subaccountCode',
          );

          // Fetch the created subaccount to check verification status
          if (subaccountCode != null) {
            try {
              final subaccountDetails = await paystackService.getSubaccount(
                subaccountCode,
              );
              if (subaccountDetails != null) {
                final settlementBank = subaccountDetails['settlement_bank'];

                print('✅ Subaccount created successfully:');
                print('   Settlement Bank: $settlementBank');

                // For South African accounts, verification is not supported by Paystack
                // Show success message if subaccount was created
                if (settlementBank != null) {
                  verificationMessage =
                      '✅ Banking details saved successfully. Subaccount created for split payments.';
                  print('✅ Subaccount created with settlement bank configured');
                } else {
                  verificationMessage =
                      '⚠️ Subaccount created but settlement bank not configured';
                  print(
                    '⚠️ Subaccount created but missing settlement bank details',
                  );
                }
              }
            } catch (e) {
              print('⚠️ Could not fetch subaccount status: $e');
              // Even if we can't fetch status, if subaccount was created, consider it success
              verificationMessage =
                  '✅ Banking details saved. Subaccount created successfully.';
            }
          }
        } catch (e) {
          print(
            '⚠️ DEBUG BankingDetailsDialog: Failed to create subaccount: $e',
          );

          // Parse error to provide specific feedback
          final errorString = e.toString().toLowerCase();
          if (errorString.contains('could not resolve') ||
              errorString.contains('invalid account') ||
              errorString.contains('account number')) {
            verificationMessage =
                '⚠️ Bank verification failed: Invalid account number or bank details';
          } else if (errorString.contains('network') ||
              errorString.contains('connection') ||
              errorString.contains('timeout')) {
            verificationMessage =
                '⚠️ Bank verification failed: Network error. Please check your connection';
          } else if (errorString.contains('already exists') ||
              errorString.contains('duplicate')) {
            verificationMessage =
                '⚠️ Subaccount already exists for this account';
          } else {
            verificationMessage =
                '⚠️ Bank verification failed: ${e.toString().replaceAll('Exception: ', '').replaceAll('Failed to create subaccount: ', '')}';
          }

          print('📝 Verification message: $verificationMessage');
          // Continue even if subaccount creation fails
          // Partner can still receive transfers via recipient code
        }

        // Save banking details to database
        print('💾 DEBUG BankingDetailsDialog: Saving to database...');
        print('   - user_id: ${user.id}');
        print('   - bank_name: ${_bankNameController.text}');
        print('   - bank_code: $bankCode');
        print('   - recipient_code: $recipientCode');
        print('   - subaccount_code: $subaccountCode');

        try {
          await SupabaseService.instance.client
              .from('trusted_partner_bank_accounts')
              .upsert({
                'user_id': user.id,
                'account_holder_name': _accountNameController.text.trim(),
                'bank_name': _bankNameController.text,
                'bank_code': bankCode,
                'account_type': _selectedAccountType,
                'account_number':
                    maskedAccountNumber, // Store masked account number
                'branch_code': _branchCodeController.text.trim(),
                'paystack_recipient_code': recipientCode,
                'bank_account_type': _selectedAccountType,
                'subaccount_code': subaccountCode,
                'percentage_charge': subaccountCode != null ? 90.0 : null,
                'subaccount_active': subaccountCode != null,
                'subaccount_created_at': subaccountCode != null
                    ? DateTime.now().toIso8601String()
                    : null,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              }, onConflict: 'user_id');

          print(
            '✅ DEBUG BankingDetailsDialog: Banking details saved to database successfully',
          );
        } catch (dbError) {
          print(
            '❌ DEBUG BankingDetailsDialog: Database insert failed: $dbError',
          );
          throw Exception(
            'Failed to save banking details to database: $dbError. Paystack resources were created (recipient: $recipientCode, subaccount: $subaccountCode).',
          );
        }
        if (subaccountCode != null) {
          print(
            '💳 DEBUG BankingDetailsDialog: Subaccount enabled for split payments',
          );
        }

        // Verify the banking details were saved to database
        final verifyResponse = await SupabaseService.instance.client
            .from('trusted_partner_bank_accounts')
            .select('paystack_recipient_code, branch_code, bank_account_type')
            .eq('user_id', user.id)
            .eq('is_active', true)
            .maybeSingle();

        print(
          '🔍 DEBUG BankingDetailsDialog: Verification - trusted_partner_bank_accounts record: $verifyResponse',
        );

        if (mounted) {
          // Show verification status to user
          if (verificationMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(verificationMessage),
                backgroundColor: verificationMessage.contains('✅')
                    ? Colors.green
                    : Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }

          Navigator.of(context).pop(true);
        }
      } else {
        throw Exception('Failed to save banking details');
      }
    } catch (e) {
      print('❌ DEBUG BankingDetailsDialog: Error saving banking details: $e');
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper method to mask account number for security
  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) {
      return accountNumber; // If 4 or fewer digits, return as-is
    }
    // Replace all but the last 4 digits with 'xxx'
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    final maskedLength = accountNumber.length - 4;
    final mask = 'x' * maskedLength;
    return '$mask$lastFour';
  }

  // Helper method to map Paystack bank names to our dropdown values
  String _mapBankNameToDropdown(String paystackBankName) {
    // Paystack might return full bank names, but our dropdown has shorter names
    switch (paystackBankName.toLowerCase()) {
      case 'first national bank':
      case 'fnb':
      case 'first national bank (fnb)':
        return 'FNB';
      case 'absa bank':
      case 'absa':
        return 'Absa Bank';
      case 'capitec bank':
      case 'capitec':
        return 'Capitec Bank';
      case 'nedbank':
        return 'Nedbank';
      case 'standard bank':
      case 'standard bank of south africa':
        return 'Standard Bank';
      case 'investec':
      case 'investec bank':
        return 'Investec';
      case 'african bank':
        return 'African Bank';
      case 'discovery bank':
      case 'discovery':
        return 'Discovery Bank';
      default:
        return 'Other'; // For unrecognized banks
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }
}
