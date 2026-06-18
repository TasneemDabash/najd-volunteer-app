import 'volunteer.dart';

enum TaskStatus {
  pending,
  active,
  completed;

  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return 'قيد الانتظار';
      case TaskStatus.active:
        return 'نشطة';
      case TaskStatus.completed:
        return 'مكتملة';
    }
  }

  static TaskStatus fromString(String? value) {
    if (value == null) return TaskStatus.pending;
    return TaskStatus.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => TaskStatus.pending,
    );
  }
}

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final String? locationId;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final List<String> requiredSkills;
  final DateTime date;
  final TaskStatus status;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final List<Volunteer>? assignedVolunteers;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    this.locationId,
    this.locationName,
    this.latitude,
    this.longitude,
    required this.requiredSkills,
    required this.date,
    required this.status,
    required this.createdAt,
    this.assignedAt,
    this.assignedVolunteers,
  });

  /// Best-display string for the task's location, preferring the joined location
  /// row's name over the free-text fallback.
  String get displayLocation {
    if (locationName != null && locationName!.trim().isNotEmpty) {
      return locationName!;
    }
    return location;
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      locationId: json['location_id'] as String?,
      locationName: json['location_name'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      requiredSkills: json['required_skills'] != null
          ? List<String>.from(json['required_skills'] as List)
          : [],
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
      status: TaskStatus.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      assignedAt: json['assigned_at'] != null
          ? DateTime.tryParse(json['assigned_at'] as String)
          : null,
      assignedVolunteers: null,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      if (locationId != null) 'location_id': locationId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'required_skills': requiredSkills,
      'date': date.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    String? locationId,
    String? locationName,
    double? latitude,
    double? longitude,
    List<String>? requiredSkills,
    DateTime? date,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? assignedAt,
    List<Volunteer>? assignedVolunteers,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      locationId: locationId ?? this.locationId,
      locationName: locationName ?? this.locationName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      date: date ?? this.date,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      assignedAt: assignedAt ?? this.assignedAt,
      assignedVolunteers: assignedVolunteers ?? this.assignedVolunteers,
    );
  }
}

class TaskAssignment {
  final String id;
  final String taskId;
  final String volunteerId;
  final DateTime assignedAt;

  TaskAssignment({
    required this.id,
    required this.taskId,
    required this.volunteerId,
    required this.assignedAt,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    return TaskAssignment(
      id: json['id'] as String,
      taskId: json['task_id'] as String,
      volunteerId: json['volunteer_id'] as String,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : DateTime.now(),
    );
  }
}
