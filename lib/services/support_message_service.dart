import 'package:supabase_flutter/supabase_flutter.dart';

/// Volunteer ↔ support chat via `support_chat_messages` + RPCs.
class SupportMessageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> submitMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty');
    }
    final response = await _client.rpc(
      'submit_support_message',
      params: {'p_body': trimmed},
    );
    if (response == null) {
      throw Exception('No response from server');
    }
    return response.toString();
  }

  Future<void> replyToVolunteer(String volunteerUserId, String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('Message cannot be empty');
    }
    final response = await _client.rpc(
      'support_reply_chat',
      params: {
        'p_volunteer_id': volunteerUserId,
        'p_body': trimmed,
      },
    );
    if (response == null) {
      throw Exception('No response from server');
    }
  }

  Future<List<SupportChatMessage>> listMyChatMessages() async {
    final response = await _client.rpc('list_my_support_chat');
    if (response == null) return [];
    final list = response as List;
    return list
        .map(
          (e) =>
              SupportChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<SupportChatMessage>> listThreadMessages(
    String volunteerUserId,
  ) async {
    final response = await _client.rpc(
      'list_support_chat_thread',
      params: {'p_volunteer_id': volunteerUserId},
    );
    if (response == null) return [];
    final list = response as List;
    return list
        .map(
          (e) =>
              SupportChatMessage.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  /// One row per volunteer thread (wrapper around `list_support_threads_for_coordinator`).
  Future<List<SupportThreadRow>> listForCoordinator() async {
    final response = await _client.rpc('list_support_messages_for_coordinator');
    if (response == null) return [];
    final list = response as List;
    return list
        .map((e) => SupportThreadRow.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

class SupportChatMessage {
  SupportChatMessage({
    required this.id,
    required this.threadVolunteerId,
    required this.senderId,
    required this.body,
    this.mediaType,
    this.mediaUrl,
    this.durationMs,
    required this.createdAt,
  });

  final String id;
  final String threadVolunteerId;
  final String senderId;
  final String body;
  final String? mediaType;
  final String? mediaUrl;
  final int? durationMs;
  final DateTime createdAt;

  bool get isVoice => (mediaType == 'audio') && (mediaUrl?.isNotEmpty ?? false);

  factory SupportChatMessage.fromJson(Map<String, dynamic> json) {
    return SupportChatMessage(
      id: json['id'] as String? ?? '',
      threadVolunteerId: json['thread_volunteer_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      mediaUrl: json['media_url'] as String?,
      durationMs: json['duration_ms'] is int
          ? json['duration_ms'] as int
          : (json['duration_ms'] is num
              ? (json['duration_ms'] as num).toInt()
              : null),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

class SupportThreadRow {
  SupportThreadRow({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.fromUserId,
    required this.senderEmail,
    required this.senderName,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String fromUserId;
  final String senderEmail;
  final String senderName;

  factory SupportThreadRow.fromJson(Map<String, dynamic> json) {
    return SupportThreadRow(
      id: json['id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      fromUserId: json['from_user_id'] as String? ?? '',
      senderEmail: json['sender_email'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? '',
    );
  }

  String get displaySender {
    if (senderName.trim().isNotEmpty) return senderName.trim();
    if (senderEmail.trim().isNotEmpty) return senderEmail.trim();
    return 'Volunteer';
  }
}
