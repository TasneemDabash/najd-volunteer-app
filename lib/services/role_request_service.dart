import 'package:supabase_flutter/supabase_flutter.dart';

class RoleRequest {
  final String id;
  final String userId;
  final String requestedRole;
  final String? reason;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  RoleRequest({
    required this.id,
    required this.userId,
    required this.requestedRole,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory RoleRequest.fromJson(Map<String, dynamic> json) {
    return RoleRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      requestedRole: json['requested_role'] as String,
      reason: json['reason'] as String?,
      status: json['status'] as String,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
    );
  }

  String get roleDisplayName {
    switch (requestedRole) {
      case 'admin':
        return 'مدير';
      case 'support':
        return 'دعم فني';
      case 'coordinator':
        return 'منسق';
      default:
        return requestedRole;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      default:
        return status;
    }
  }
}

class RoleRequestService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'role_requests';

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Create a new role request
  Future<RoleRequest> createRequest({
    required String requestedRole,
    String? reason,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // Check if there's already a pending request
    final existing = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    if (existing != null) {
      throw Exception('لديك طلب قيد الانتظار بالفعل');
    }

    final response = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'requested_role': requestedRole,
          'reason': reason,
        })
        .select()
        .single();

    return RoleRequest.fromJson(response);
  }

  /// Get user's role requests
  Future<List<RoleRequest>> getMyRequests() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((e) => RoleRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cancel a pending request
  Future<void> cancelRequest(String requestId) async {
    await _client.from(_table).delete().eq('id', requestId).eq('status', 'pending');
  }

  /// Get all pending requests (admin only)
  Future<List<RoleRequest>> getPendingRequests() async {
    try {
      final response = await _client.rpc('list_pending_role_requests');
      return (response as List)
          .map((e) => RoleRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback to direct query if RPC not available
      final response = await _client
          .from(_table)
          .select('*, profiles!role_requests_user_id_fkey(full_name, email)')
          .eq('status', 'pending')
          .order('created_at');

      return (response as List).map((e) {
        final data = Map<String, dynamic>.from(e as Map);
        final profile = data['profiles'] as Map<String, dynamic>?;
        data['user_name'] = profile?['full_name'];
        data['user_email'] = profile?['email'];
        return RoleRequest.fromJson(data);
      }).toList();
    }
  }

  /// Approve a role request (admin only)
  Future<void> approveRequest(String requestId) async {
    try {
      await _client.rpc('approve_role_request', params: {'request_id': requestId});
    } catch (e) {
      // Fallback: manual update
      final request = await _client
          .from(_table)
          .select()
          .eq('id', requestId)
          .single();

      await _client.from(_table).update({
        'status': 'approved',
        'reviewed_by': currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      // Update user role
      await _client.from('profiles').update({
        'role': request['requested_role'],
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', request['user_id']);
    }
  }

  /// Reject a role request (admin only)
  Future<void> rejectRequest(String requestId, {String? reason}) async {
    try {
      await _client.rpc('reject_role_request', params: {
        'request_id': requestId,
        'reason': reason,
      });
    } catch (e) {
      // Fallback: manual update
      await _client.from(_table).update({
        'status': 'rejected',
        'reviewed_by': currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    }
  }
}
