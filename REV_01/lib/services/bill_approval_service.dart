import 'package:supabase_flutter/supabase_flutter.dart';

class BillApproval {
  final String id;
  final String billId;
  final String partnerId;
  final String status;
  final String? reviewNotes;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  BillApproval({
    required this.id,
    required this.billId,
    required this.partnerId,
    required this.status,
    this.reviewNotes,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillApproval.fromMap(Map<String, dynamic> map) {
    return BillApproval(
      id: map['id'],
      billId: map['bill_id'],
      partnerId: map['partner_id'],
      status: map['status'],
      reviewNotes: map['review_notes'],
      reviewedAt: map['reviewed_at'] != null
          ? DateTime.parse(map['reviewed_at'])
          : null,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class BillApprovalService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get pending approvals for a partner
  Future<List<Map<String, dynamic>>> getPendingApprovals(
    String partnerId,
  ) async {
    try {
      final response = await _supabase
          .from('bill_approvals')
          .select('''
            *,
            processed_bills (
              id,
              receipt_data,
              original_total,
              discount_amount,
              discounted_total,
              image_url,
              processed_at,
              member:profiles!processed_bills_user_id_fkey (
                id,
                name,
                surname,
                email
              )
            )
          ''')
          .eq('partner_id', partnerId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Approve a bill
  Future<void> approveBill({
    required String approvalId,
    String? reviewNotes,
  }) async {
    try {
      await _supabase
          .from('bill_approvals')
          .update({
            'status': 'approved',
            'review_notes': reviewNotes,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', approvalId);
    } catch (e) {
      throw Exception('Failed to approve bill: $e');
    }
  }

  /// Reject a bill
  Future<void> rejectBill({
    required String approvalId,
    required String rejectionReason,
    String? reviewNotes,
  }) async {
    try {
      await _supabase
          .from('bill_approvals')
          .update({
            'status': 'rejected',
            'review_notes': reviewNotes ?? rejectionReason,
            'reviewed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', approvalId);

      // Also update the processed bill with rejection reason
      final approval = await _supabase
          .from('bill_approvals')
          .select('bill_id')
          .eq('id', approvalId)
          .single();

      await _supabase
          .from('processed_bills')
          .update({'rejection_reason': rejectionReason})
          .eq('id', approval['bill_id']);
    } catch (e) {
      throw Exception('Failed to reject bill: $e');
    }
  }

  /// Mark bill as paid in-app
  Future<void> markBillAsPaidInApp({
    required String billId,
    required String paymentId,
  }) async {
    try {
      await _supabase
          .from('processed_bills')
          .update({'payment_method': 'in_app', 'payment_id': paymentId})
          .eq('id', billId);
    } catch (e) {
      throw Exception('Failed to mark bill as paid: $e');
    }
  }

  /// Mark bill as paid physically
  Future<void> markBillAsPaidPhysically(String billId) async {
    try {
      await _supabase
          .from('processed_bills')
          .update({'payment_method': 'physical'})
          .eq('id', billId);
    } catch (e) {
      throw Exception('Failed to mark bill as paid physically: $e');
    }
  }

  /// Get approved bills for a member that are ready for payment
  Future<List<Map<String, dynamic>>> getApprovedBillsForMember(
    String memberId,
  ) async {
    try {
      final response = await _supabase
          .from('bill_approvals')
          .select('''
            *,
            processed_bills!inner (
              id,
              receipt_data,
              original_total,
              discount_amount,
              discounted_total,
              image_url,
              processed_at,
              member:profiles!processed_bills_member_id_fkey (
                id,
                name,
                surname,
                email
              ),
              partner:profiles!processed_bills_partner_id_fkey (
                id,
                name,
                surname,
                email
              )
            )
          ''')
          .eq('status', 'approved')
          .eq('processed_bills.member_id', memberId)
          .order('reviewed_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Get approval statistics for a partner
  Future<Map<String, dynamic>> getApprovalStats(String partnerId) async {
    try {
      final response = await _supabase
          .from('bill_approvals')
          .select('status')
          .eq('partner_id', partnerId);

      final stats = {'pending': 0, 'approved': 0, 'rejected': 0};
      for (final approval in response as List) {
        final status = approval['status'] as String;
        if (stats.containsKey(status)) {
          stats[status] = (stats[status] as int) + 1;
        }
      }

      return stats;
    } catch (e) {
      return {'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }
}
