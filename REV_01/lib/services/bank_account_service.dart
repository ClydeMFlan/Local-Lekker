import 'package:supabase_flutter/supabase_flutter.dart';

class BankAccount {
  final String id;
  final String businessId;
  final String accountHolderName;
  final String bankName;
  final String accountType;
  final String accountNumber;
  final String branchCode;
  final String? paystackPublicKey;
  final String? paystackSecretKey;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  BankAccount({
    required this.id,
    required this.businessId,
    required this.accountHolderName,
    required this.bankName,
    required this.accountType,
    required this.accountNumber,
    required this.branchCode,
    this.paystackPublicKey,
    this.paystackSecretKey,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'],
      businessId: map['business_id'],
      accountHolderName: map['account_holder_name'],
      bankName: map['bank_name'],
      accountType: map['account_type'],
      accountNumber: map['account_number'],
      branchCode: map['branch_code'],
      paystackPublicKey: map['paystack_public_key'],
      paystackSecretKey: map['paystack_secret_key'],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'business_id': businessId,
      'account_holder_name': accountHolderName,
      'bank_name': bankName,
      'account_type': accountType,
      'account_number': accountNumber,
      'branch_code': branchCode,
      'paystack_public_key': paystackPublicKey,
      'paystack_secret_key': paystackSecretKey,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BankAccountService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Save or update bank account for a business
  Future<BankAccount> saveBankAccount({
    required String businessId,
    required String accountHolderName,
    required String bankName,
    required String accountType,
    required String accountNumber,
    required String branchCode,
    String? paystackPublicKey,
    String? paystackSecretKey,
  }) async {
    try {
      final accountData = {
        'business_id': businessId,
        'account_holder_name': accountHolderName,
        'bank_name': bankName,
        'account_type': accountType,
        'account_number': accountNumber,
        'branch_code': branchCode,
        'paystack_public_key': paystackPublicKey,
        'paystack_secret_key': paystackSecretKey,
        'is_active': true,
      };

      final response = await _supabase
          .from('trusted_partner_bank_accounts')
          .upsert(
            accountData,
            onConflict: 'business_id,account_number,branch_code',
          )
          .select()
          .single();

      return BankAccount.fromMap(response);
    } catch (e) {
      throw Exception('Failed to save bank account: $e');
    }
  }

  /// Get bank accounts for a business
  Future<List<BankAccount>> getBusinessBankAccounts(String businessId) async {
    try {
      final response = await _supabase
          .from('trusted_partner_bank_accounts')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((account) => BankAccount.fromMap(account))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get active bank account for a business (returns the most recent)
  Future<BankAccount?> getActiveBankAccount(String businessId) async {
    try {
      final accounts = await getBusinessBankAccounts(businessId);
      return accounts.isNotEmpty ? accounts.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Deactivate a bank account
  Future<void> deactivateBankAccount(String accountId) async {
    try {
      await _supabase
          .from('trusted_partner_bank_accounts')
          .update({'is_active': false})
          .eq('id', accountId);
    } catch (e) {
      throw Exception('Failed to deactivate bank account: $e');
    }
  }
}
