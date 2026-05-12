import 'dart:math' as math;

/// A controlled location entry from `public.locations`.
///
/// Used by the volunteer location picker and accident/task location picker so
/// users never type free-text addresses. Optional [latitude]/[longitude] enable
/// "nearest volunteer" distance calculations.
class AppLocation {
  final String id;
  final String name;
  final String region;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const AppLocation({
    required this.id,
    required this.name,
    this.region = '',
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  String get displayName => region.isEmpty ? name : '$name · $region';

  factory AppLocation.fromJson(Map<String, dynamic> json) {
    return AppLocation(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'latitude': latitude,
        'longitude': longitude,
        'is_active': isActive,
      };

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

/// Haversine distance in kilometers between two coordinates.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.asin(math.min(1.0, math.sqrt(a)));
  return earthRadiusKm * c;
}
