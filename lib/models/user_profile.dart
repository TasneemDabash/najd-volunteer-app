import 'user_role.dart';

class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final List<String> skills;
  final List<String> availability;
  final String? notes;
  final UserRole role;
  final String status;

  // Presence + location (added in migrate_locations_calls_voice.sql).
  final bool isOnline;
  final bool isAvailable;
  final DateTime? lastSeen;
  final String? currentLocationId;
  final double? latitude;
  final double? longitude;

  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.city,
    required this.skills,
    required this.availability,
    required this.notes,
    required this.role,
    required this.status,
    this.isOnline = false,
    this.isAvailable = true,
    this.lastSeen,
    this.currentLocationId,
    this.latitude,
    this.longitude,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      skills: json['skills'] != null
          ? List<String>.from(json['skills'] as List)
          : const [],
      availability: json['availability'] != null
          ? List<String>.from(json['availability'] as List)
          : const [],
      notes: json['notes'] as String?,
      role: UserRole.fromString(json['role'] as String?),
      status: json['status'] as String? ?? 'active',
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      currentLocationId: json['current_location_id'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
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
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'city': city,
      'skills': skills,
      'availability': availability,
      'notes': notes,
      'role': role.value,
      'status': status,
      'is_online': isOnline,
      'is_available': isAvailable,
      'last_seen': lastSeen?.toIso8601String(),
      'current_location_id': currentLocationId,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? city,
    List<String>? skills,
    List<String>? availability,
    String? notes,
    UserRole? role,
    String? status,
    bool? isOnline,
    bool? isAvailable,
    DateTime? lastSeen,
    String? currentLocationId,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      skills: skills ?? this.skills,
      availability: availability ?? this.availability,
      notes: notes ?? this.notes,
      role: role ?? this.role,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      lastSeen: lastSeen ?? this.lastSeen,
      currentLocationId: currentLocationId ?? this.currentLocationId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
