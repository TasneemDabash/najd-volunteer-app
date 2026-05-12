import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_location.dart';

/// Reads the controlled list of locations volunteers/coordinators can pick from.
///
/// Locations live in `public.locations` and are seeded by the migration. RLS
/// allows any authenticated user to SELECT, admins to write.
class LocationService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'locations';

  Future<List<AppLocation>> list({bool includeInactive = false}) async {
    var query = _client.from(_table).select();
    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    final response = await query.order('name');
    return (response as List)
        .map((e) => AppLocation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AppLocation?> getById(String id) async {
    final response =
        await _client.from(_table).select().eq('id', id).maybeSingle();
    if (response == null) return null;
    return AppLocation.fromJson(Map<String, dynamic>.from(response));
  }
}
