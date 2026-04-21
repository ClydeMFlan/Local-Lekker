import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/discount.dart';

class DiscountService {
  static final DiscountService _instance = DiscountService._internal();
  factory DiscountService() => _instance;
  DiscountService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Discount>> getTrustedPartnerDiscounts(
    String trustedPartnerId,
  ) async {
    try {
      final response = await _supabase
          .from('trusted_partner_discounts')
          .select()
          .eq('trusted_partner_id', trustedPartnerId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return response.map((json) => Discount.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load discounts: $e');
    }
  }

  Future<Discount> createDiscount({
    required String trustedPartnerId,
    required String name,
    required String description,
    required double percentage,
    double? fixedAmount,
  }) async {
    try {
      final response = await _supabase
          .from('trusted_partner_discounts')
          .insert({
            'trusted_partner_id': trustedPartnerId,
            'name': name,
            'description': description,
            'percentage': percentage,
            'fixed_amount': fixedAmount,
            'is_active': true,
          })
          .select()
          .single();

      return Discount.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create discount: $e');
    }
  }

  Future<void> updateDiscount(
    String discountId, {
    String? name,
    String? description,
    double? percentage,
    double? fixedAmount,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (percentage != null) updates['percentage'] = percentage;
      if (fixedAmount != null) updates['fixed_amount'] = fixedAmount;
      if (isActive != null) updates['is_active'] = isActive;
      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase
          .from('trusted_partner_discounts')
          .update(updates)
          .eq('id', discountId);
    } catch (e) {
      throw Exception('Failed to update discount: $e');
    }
  }

  Future<List<Discount>> getAllTrustedPartnerDiscounts(
    String trustedPartnerId,
  ) async {
    try {
      final response = await _supabase
          .from('trusted_partner_discounts')
          .select()
          .eq('trusted_partner_id', trustedPartnerId)
          .order('created_at', ascending: false);

      return response.map((json) => Discount.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load discounts: $e');
    }
  }

  Future<void> deleteDiscount(String discountId) async {
    try {
      await _supabase
          .from('trusted_partner_discounts')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', discountId);
    } catch (e) {
      throw Exception('Failed to delete discount: $e');
    }
  }

  Future<List<Map<String, dynamic>>>
  getAllActiveDiscountsWithTrustedPartners() async {
    try {
      // First get all active discounts
      final discountsResponse = await _supabase
          .from('trusted_partner_discounts')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      // Get unique trusted partner IDs
      final trustedPartnerIds = discountsResponse
          .map((d) => d['trusted_partner_id'] as String)
          .toSet()
          .toList();

      if (trustedPartnerIds.isEmpty) {
        return [];
      }

      // Get trusted partner info for these IDs
      List<Map<String, dynamic>> trustedPartnersResponse = [];
      for (final trustedPartnerId in trustedPartnerIds) {
        final trustedPartner = await _supabase
            .from('businesses')
            .select('owner_member_id, name')
            .eq('owner_member_id', trustedPartnerId)
            .maybeSingle();
        if (trustedPartner != null) {
          trustedPartnersResponse.add(trustedPartner);
        }
      }

      // Create a map of trusted_partner_id -> business_name
      final trustedPartnerMap = {
        for (final trustedPartner in trustedPartnersResponse)
          trustedPartner['owner_member_id'] as String:
              trustedPartner['name'] as String,
      };

      // Combine the data
      return discountsResponse.map((discount) {
        final trustedPartnerId = discount['trusted_partner_id'] as String;
        return {
          ...discount,
          'trusted_partners': {
            'business_name':
                trustedPartnerMap[trustedPartnerId] ??
                'Unknown Trusted Partner',
          },
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to load active discounts: $e');
    }
  }
}
