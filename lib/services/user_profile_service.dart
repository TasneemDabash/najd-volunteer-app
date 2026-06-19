import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/volunteer.dart';

class UserProfileService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'profiles';

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final response =
        await _client.from(_table).select().eq('id', userId).maybeSingle();
    return response;
  }

  Future<void> upsertProfile({
    required String fullName,
    required String phone,
    required String city,
    required List<String> skills,
    required List<String> availability,
    String? notes,
    String? currentLocationId,
    double? latitude,
    double? longitude,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    final now = DateTime.now().toIso8601String();
    final data = {
      'id': userId,
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'skills': skills,
      'availability': availability,
      'notes': notes,
      'updated_at': now,
      if (currentLocationId != null) 'current_location_id': currentLocationId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    await _client.from(_table).upsert(data, onConflict: 'id');
  }

  Future<Volunteer?> getProfileAsVolunteer() async {
    final map = await getProfile();
    if (map == null) return null;
    return Volunteer(
      id: map['id'] as String? ?? '',
      fullName: map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      city: map['city'] as String? ?? '',
      appRole: map['role'] as String?,
      skills:
          map['skills'] != null ? List<String>.from(map['skills'] as List) : [],
      availability: map['availability'] != null
          ? List<String>.from(map['availability'] as List)
          : [],
      notes: map['notes'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }
}
