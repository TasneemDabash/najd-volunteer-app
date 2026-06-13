import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';

class AccountService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _profilesTable = 'profiles';

  String? get currentUserId => _client.auth.currentUser?.id;

  Future<UserProfile?> getProfile() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final response = await _client
        .from(_profilesTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> getOrCreateProfile({
    String? email,
    String? fullName,
    String? phone,
    String? city,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw Exception('Not authenticated');
    }

    final existing = await getProfile();
    if (existing != null) return existing;

    final now = DateTime.now().toIso8601String();
    final data = {
      'id': userId,
      'full_name': fullName ?? '',
      'email': email ?? _client.auth.currentUser?.email ?? '',
      'phone': phone ?? '',
      'city': city ?? '',
      'skills': <String>[],
      'availability': <String>[],
      'notes': null,
      'role': UserRole.volunteer.value,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    };

    final response =
        await _client.from(_profilesTable).insert(data).select().single();
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> updateRole({
    required String userId,
    required UserRole role,
  }) async {
    final response = await _client
        .from(_profilesTable)
        .update({
          'role': role.value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return UserProfile.fromJson(response);
  }

  Future<UserProfile> updateStatus({
    required String userId,
    required String status,
  }) async {
    final response = await _client
        .from(_profilesTable)
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', userId)
        .select()
        .single();
    return UserProfile.fromJson(response);
  }

  static List<UserProfile> _mapRpcProfileRows(dynamic response) {
    if (response == null) return [];
    if (response is Map) {
      return [
        UserProfile.fromJson(Map<String, dynamic>.from(response)),
      ];
    }
    final list = response as List;
    return list
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Lists every profile for **User management**. Uses RPC only — never falls back to
  /// `.from('profiles')` (RLS would hide everyone except you and look "broken").
  ///
  /// Tries [list_profiles_for_coordinator] first (admin + support), then
  /// [admin_list_all_profiles], so a partial SQL run still works.
  Future<List<UserProfile>> fetchAllProfilesForManagement() async {
    Object? errCoordinator;
    try {
      final response = await _client.rpc('list_profiles_for_coordinator');
      return _mapRpcProfileRows(response);
    } catch (e) {
      errCoordinator = e;
    }
    try {
      final response = await _client.rpc('admin_list_all_profiles');
      return _mapRpcProfileRows(response);
    } catch (eAdmin) {
      throw Exception(
        'Supabase does not have the profile-list functions yet (or the API cache is stale).\n\n'
        'Fix:\n'
        '1. Open your project in supabase.com → SQL Editor.\n'
        '2. Paste the ENTIRE file from your computer: najd/supabase/rpc_profiles_coordinator.sql\n'
        '3. Click Run (you should see "Success").\n'
        '4. Wait a minute, or Dashboard → Project Settings → API → note your URL (sometimes cache refreshes on deploy).\n'
        '5. Fully restart the app (stop flutter run, start again).\n\n'
        'Errors from your project:\n'
        '• list_profiles_for_coordinator: $errCoordinator\n'
        '• admin_list_all_profiles: $eAdmin',
      );
    }
  }

  /// Prefer RPC so updates work even when RLS blocks direct table updates.
  Future<UserProfile> updateRoleAsAdmin({
    required String userId,
    required UserRole role,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_set_profile_role_and_status',
        params: {
          'p_user_id': userId,
          'p_role': role.value,
        },
      );
      if (response != null) {
        return UserProfile.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
      }
    } catch (_) {}
    return updateRole(userId: userId, role: role);
  }

  Future<UserProfile> updateStatusAsAdmin({
    required String userId,
    required String status,
  }) async {
    try {
      final response = await _client.rpc(
        'admin_set_profile_role_and_status',
        params: {
          'p_user_id': userId,
          'p_status': status,
        },
      );
      if (response != null) {
        return UserProfile.fromJson(
          Map<String, dynamic>.from(response as Map),
        );
      }
    } catch (_) {}
    return updateStatus(userId: userId, status: status);
  }
}
