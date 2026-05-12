import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call_session.dart';

/// Signalling layer for voice/video calls.
///
/// The actual media stack (Agora / WebRTC / Twilio) is not wired up yet — this
/// service only manages call sessions in Supabase (`call_sessions`) and creates
/// in-app notifications via the `start_call` RPC. The CallScreen renders a
/// placeholder UI that uses [channelName] as the room key once a media SDK is
/// plugged in.
class CallService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<CallSession> startCall({
    required String calleeId,
    required CallType type,
  }) async {
    final response = await _client.rpc('start_call', params: {
      'p_callee_id': calleeId,
      'p_call_type': type.value,
    });
    if (response == null) {
      throw Exception('Failed to start call');
    }
    final raw =
        response is List ? response.first as Map<String, dynamic> : response;
    return CallSession.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<CallSession> updateStatus({
    required String callId,
    required CallStatus status,
  }) async {
    final response = await _client.rpc('update_call_status', params: {
      'p_call_id': callId,
      'p_status': status.value,
    });
    final raw =
        response is List ? response.first as Map<String, dynamic> : response;
    return CallSession.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  /// Subscribes to incoming calls (callee_id = me). Caller passes a handler.
  RealtimeChannel subscribeIncoming(void Function(CallSession) onCall) {
    final uid = _client.auth.currentUser?.id;
    return _client
        .channel('calls_inbox_${uid ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'call_sessions',
          filter: uid == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'callee_id',
                  value: uid,
                ),
          callback: (payload) {
            final raw = payload.newRecord;
            if (raw.isEmpty) return;
            try {
              onCall(CallSession.fromJson(Map<String, dynamic>.from(raw)));
            } catch (_) {}
          },
        )
        .subscribe();
  }

  /// Subscribes to status updates of a specific call session (both peers use
  /// this to know when the other accepted / hung up).
  RealtimeChannel subscribeSession(
    String callId,
    void Function(CallSession) onUpdate,
  ) {
    return _client
        .channel('call_session_$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'call_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) {
            final raw = payload.newRecord;
            if (raw.isEmpty) return;
            try {
              onUpdate(CallSession.fromJson(Map<String, dynamic>.from(raw)));
            } catch (_) {}
          },
        )
        .subscribe();
  }
}
