class Volunteer {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String city;
  final List<String> skills;
  final List<String> availability;
  final String? notes;

  /// From `profiles.role` when listing via coordinator RPC (admin/support).
  final String? appRole;

  /// Account status (`active` / `inactive` / `deactivated`).
  final String? status;

  /// Live presence + location fields.
  final bool isOnline;
  final bool isAvailable;
  final DateTime? lastSeen;
  final String? currentLocationId;
  final String? currentLocationName;
  final String? currentLocationRegion;
  final double? latitude;
  final double? longitude;

  /// Optional distance to an origin point in kilometers (populated by
  /// `list_volunteers_for_coordinator`).
  final double? distanceKm;

  final DateTime createdAt;

  Volunteer({
    required this.id,
    required this.fullName,
    this.email = '',
    required this.phone,
    required this.city,
    required this.skills,
    required this.availability,
    this.notes,
    this.appRole,
    this.status,
    this.isOnline = false,
    this.isAvailable = true,
    this.lastSeen,
    this.currentLocationId,
    this.currentLocationName,
    this.currentLocationRegion,
    this.latitude,
    this.longitude,
    this.distanceKm,
    required this.createdAt,
  });

  factory Volunteer.fromJson(Map<String, dynamic> json) {
    return Volunteer(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      skills: json['skills'] != null
          ? List<String>.from(json['skills'] as List)
          : [],
      availability: json['availability'] != null
          ? List<String>.from(json['availability'] as List)
          : [],
      notes: json['notes'] as String?,
      appRole: json['role'] as String?,
      status: json['status'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? true,
      lastSeen: json['last_seen'] != null
          ? DateTime.tryParse(json['last_seen'] as String)
          : null,
      currentLocationId: json['current_location_id'] as String?,
      currentLocationName: json['location_name'] as String?,
      currentLocationRegion: json['location_region'] as String?,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      distanceKm: _toDouble(json['distance_km']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  Volunteer copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? city,
    List<String>? skills,
    List<String>? availability,
    String? notes,
    String? appRole,
    String? status,
    bool? isOnline,
    bool? isAvailable,
    DateTime? lastSeen,
    String? currentLocationId,
    String? currentLocationName,
    String? currentLocationRegion,
    double? latitude,
    double? longitude,
    double? distanceKm,
    DateTime? createdAt,
  }) {
    return Volunteer(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      city: city ?? this.city,
      skills: skills ?? this.skills,
      availability: availability ?? this.availability,
      notes: notes ?? this.notes,
      appRole: appRole ?? this.appRole,
      status: status ?? this.status,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      lastSeen: lastSeen ?? this.lastSeen,
      currentLocationId: currentLocationId ?? this.currentLocationId,
      currentLocationName: currentLocationName ?? this.currentLocationName,
      currentLocationRegion:
          currentLocationRegion ?? this.currentLocationRegion,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

const List<String> skillOptions = [
  'Medical',
  'Logistics',
  'Driving',
  'Translation',
  'Media',
  'Technical',
  'General Help',
];

const List<String> availabilityOptions = [
  'Morning',
  'Afternoon',
  'Evening',
  'Weekends',
  'Emergency Only',
];
