import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';

/// Toggle online/offline, availability and current location for the signed-in
/// user via the `set_my_presence` RPC.
///
/// Coordinators see these fields through `list_volunteers_for_coordinator`.
class PresenceService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<UserProfile?> setPresence({
    bool? isOnline,
    bool? isAvailable,
    String? currentLocationId,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'set_my_presence',
      params: {
        'p_is_online': isOnline,
        'p_is_available': isAvailable,
        'p_current_location_id': currentLocationId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    if (response == null) return null;
    final raw = response is List
        ? (response.isNotEmpty ? response.first : null)
        : response;
    if (raw == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(raw as Map));
  }

  Future<UserProfile?> goOnline() =>
      setPresence(isOnline: true, isAvailable: true);

  Future<UserProfile?> goOffline() =>
      setPresence(isOnline: false);
}
