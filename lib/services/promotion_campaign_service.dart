import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PromotionCampaignService {
  static final PromotionCampaignService _instance =
      PromotionCampaignService._internal();
  factory PromotionCampaignService() => _instance;
  PromotionCampaignService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final Logger _logger = Logger();

  Future<Map<String, dynamic>?> getEligibleIntroCampaign({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    try {
      final response = await _client
          .from('promotion_participant_emails')
          .select(
            'id, promotion_id, is_claimed, promotions(id, name, free_months, is_active, starts_at, ends_at, initial_charge_cents, renewal_charge_cents, is_intro_campaign)',
          )
          .eq('email', normalizedEmail)
          .eq('is_claimed', false)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      for (final row in response) {
        final map = Map<String, dynamic>.from(row);
        final promotionRaw = map['promotions'];
        if (promotionRaw == null) {
          continue;
        }

        final promotion = Map<String, dynamic>.from(promotionRaw as Map);
        if (promotion['is_intro_campaign'] != true ||
            promotion['is_active'] != true) {
          continue;
        }

        final startsAt = promotion['starts_at'] as String?;
        if (startsAt != null && DateTime.parse(startsAt).isAfter(now)) {
          continue;
        }

        final endsAt = promotion['ends_at'] as String?;
        if (endsAt != null && DateTime.parse(endsAt).isBefore(now)) {
          continue;
        }

        return {
          'participant_id': map['id'],
          'promotion': promotion,
        };
      }

      return null;
    } catch (e) {
      _logger.e('PromotionCampaignService.getEligibleIntroCampaign error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> importParticipantEmails({
    required String promotionId,
    required String rawInput,
  }) async {
    final parsed = _parseEmails(rawInput);
    if (parsed['validEmails'].isEmpty) {
      return parsed;
    }

    final validEmails = (parsed['validEmails'] as List<String>);

    int inserted = 0;
    int alreadyExists = 0;

    for (final email in validEmails) {
      try {
        await _client.from('promotion_participant_emails').insert({
          'promotion_id': promotionId,
          'email': email,
        });
        inserted++;
      } catch (e) {
        final message = e.toString().toLowerCase();
        if (message.contains('duplicate') || message.contains('unique')) {
          alreadyExists++;
        } else {
          _logger.w(
            'PromotionCampaignService: failed to insert $email for $promotionId: $e',
          );
        }
      }
    }

    return {
      ...parsed,
      'inserted': inserted,
      'alreadyExists': alreadyExists,
    };
  }

  /// Returns all promotions the given member email is eligible to see.
  /// Only promotions where the email exists in [promotion_participant_emails]
  /// are returned — admin controls who sees which promotion.
  Future<List<Map<String, dynamic>>> getEligiblePromotionsForEmail({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return [];

    try {
      final response = await _client
          .from('promotion_participant_emails')
          .select('promotion_id, promotions!inner(*)')
          .eq('email', normalizedEmail);

      final now = DateTime.now();
      final promotions = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final row in response) {
        final promotionRaw = row['promotions'];
        if (promotionRaw == null) continue;

        final promo = Map<String, dynamic>.from(promotionRaw as Map);
        final id = promo['id'] as String?;
        if (id == null || seenIds.contains(id)) continue;

        if (promo['is_active'] != true) continue;

        final endsAt = promo['ends_at'] as String?;
        if (endsAt != null && DateTime.parse(endsAt).isBefore(now)) continue;

        seenIds.add(id);
        promotions.add(promo);
      }

      // Sort newest first (mirrors the home page ordering)
      promotions.sort((a, b) {
        final aDate = a['created_at'] as String? ?? '';
        final bDate = b['created_at'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

      return promotions;
    } catch (e) {
      _logger.e('PromotionCampaignService.getEligiblePromotionsForEmail error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPromotionParticipants({
    required String promotionId,
  }) async {
    final response = await _client
        .from('promotion_participant_emails')
        .select('id, email, is_claimed, claimed_by, claimed_at, created_at')
        .eq('promotion_id', promotionId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markParticipantClaimed({
    required String participantId,
    required String userId,
  }) async {
    await _client
        .from('promotion_participant_emails')
        .update({
          'is_claimed': true,
          'claimed_by': userId,
          'claimed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', participantId);
  }

  Future<void> deleteParticipantEmail({
    required String participantId,
  }) async {
    await _client
        .from('promotion_participant_emails')
        .delete()
        .eq('id', participantId);
  }

  Map<String, dynamic> _parseEmails(String rawInput) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final values = rawInput
        .split(RegExp(r'[\n,;]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final valid = <String>[];
    final invalid = <String>[];
    int duplicates = 0;

    for (final email in values) {
      if (seen.contains(email)) {
        duplicates++;
        continue;
      }
      seen.add(email);

      if (emailRegex.hasMatch(email)) {
        valid.add(email);
      } else {
        invalid.add(email);
      }
    }

    return {
      'totalInput': values.length,
      'validEmails': valid,
      'invalidEmails': invalid,
      'duplicates': duplicates,
    };
  }
}
