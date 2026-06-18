class TaskPublishRequest {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String location;
  final String? locationId;
  final double? latitude;
  final double? longitude;
  final List<String> requiredSkills;
  final DateTime? scheduledDate;
  final String? reason;
  final String status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String? createdTaskId;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  TaskPublishRequest({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.location,
    this.locationId,
    this.latitude,
    this.longitude,
    required this.requiredSkills,
    this.scheduledDate,
    this.reason,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    this.createdTaskId,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory TaskPublishRequest.fromJson(Map<String, dynamic> json) {
    return TaskPublishRequest(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      locationId: json['location_id'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      requiredSkills: json['required_skills'] != null
          ? List<String>.from(json['required_skills'] as List)
          : [],
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.tryParse(json['scheduled_date'] as String)
          : null,
      reason: json['reason'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      createdTaskId: json['created_task_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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
