enum CallType {
  voice,
  video;

  String get value => this == CallType.video ? 'video' : 'voice';

  static CallType fromString(String? v) {
    if (v == null) return CallType.voice;
    return v.toLowerCase() == 'video' ? CallType.video : CallType.voice;
  }
}

enum CallStatus {
  ringing,
  answered,
  declined,
  ended,
  missed,
  cancelled;

  String get value => name;

  static CallStatus fromString(String? v) {
    if (v == null) return CallStatus.ended;
    return CallStatus.values.firstWhere(
      (s) => s.name == v.toLowerCase(),
      orElse: () => CallStatus.ended,
    );
  }
}

class CallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final CallType callType;
  final CallStatus status;
  final String? channelName;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.status,
    this.channelName,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      callType: CallType.fromString(json['call_type'] as String?),
      status: CallStatus.fromString(json['status'] as String?),
      channelName: json['channel_name'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : DateTime.now(),
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'] as String)
          : null,
    );
  }
}
