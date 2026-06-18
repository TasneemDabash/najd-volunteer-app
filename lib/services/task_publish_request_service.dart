import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_publish_request.dart';

class TaskPublishRequestService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'task_publish_requests';

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<TaskPublishRequest> createRequest({
    required String title,
    required String description,
    required String location,
    String? locationId,
    double? latitude,
    double? longitude,
    required List<String> requiredSkills,
    required DateTime scheduledDate,
    String? reason,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('غير مسجل الدخول');

    final existing = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();

    if (existing != null) {
      throw Exception('لديك طلب نشر قيد الانتظار بالفعل');
    }

    final response = await _client
        .from(_table)
        .insert({
          'user_id': userId,
          'title': title,
          'description': description,
          'location': location,
          if (locationId != null) 'location_id': locationId,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'required_skills': requiredSkills,
          'scheduled_date': scheduledDate.toIso8601String(),
          'reason': reason,
        })
        .select()
        .single();

    return TaskPublishRequest.fromJson(response);
  }

  Future<List<TaskPublishRequest>> getMyRequests() async {
    final userId = currentUserId;
    if (userId == null) throw Exception('غير مسجل الدخول');

    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List)
          .map((e) => TaskPublishRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> hasPendingRequest() async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final row = await _client
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  Future<List<TaskPublishRequest>> getPendingRequests() async {
    try {
      final response = await _client.rpc('list_pending_task_publish_requests');
      return (response as List)
          .map((e) => TaskPublishRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      try {
        final response = await _client
            .from(_table)
            .select('*, profiles!task_publish_requests_user_id_fkey(full_name, email)')
            .eq('status', 'pending')
            .order('created_at');
        return (response as List).map((e) {
          final data = Map<String, dynamic>.from(e as Map);
          final profile = data['profiles'] as Map<String, dynamic>?;
          data['user_name'] = profile?['full_name'];
          data['user_email'] = profile?['email'];
          return TaskPublishRequest.fromJson(data);
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<String?> approveRequest(String requestId) async {
    try {
      final result = await _client.rpc('approve_task_publish_request',
          params: {'request_id': requestId});
      if (result is Map && result['task_id'] != null) {
        return result['task_id'] as String;
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId, {String? reason}) async {
    try {
      await _client.rpc('reject_task_publish_request', params: {
        'request_id': requestId,
        'reason': reason,
      });
    } catch (e) {
      await _client.from(_table).update({
        'status': 'rejected',
        'reviewed_by': currentUserId,
        'reviewed_at': DateTime.now().toIso8601String(),
        'rejection_reason': reason,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId).eq('status', 'pending');
    }
  }
}
