import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/app_location.dart';
import '../../models/user_profile.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/presence_service.dart';
import '../../services/user_profile_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/location_picker.dart';

/// Volunteer-facing availability hub:
///   – Toggle online/offline (writes to `profiles.is_online`).
///   – Toggle "Available for new tasks" (`profiles.is_available`).
///   – Pick current location from the controlled `locations` table.
///   – Edit weekly availability chips (Morning/Afternoon/...).
///
/// Replaces the previous "Schedule" tab which was a duplicate of the profile
/// screen.
class MyAvailabilityScreen extends StatefulWidget {
  const MyAvailabilityScreen({super.key});

  @override
  State<MyAvailabilityScreen> createState() => _MyAvailabilityScreenState();
}

class _MyAvailabilityScreenState extends State<MyAvailabilityScreen> {
  final PresenceService _presence = PresenceService();
  final UserProfileService _profileService = UserProfileService();
  final LocationService _locationService = LocationService();

  bool _loading = true;
  bool _saving = false;
  bool _isOnline = false;
  bool _isAvailable = true;
  String? _locationId;
  AppLocation? _locationDetail;
  DateTime? _lastSeen;
  List<String> _availability = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _profileService.getProfile();
      if (raw != null) {
        final profile = UserProfile.fromJson(Map<String, dynamic>.from(raw));
        _isOnline = profile.isOnline;
        _isAvailable = profile.isAvailable;
        _locationId = profile.currentLocationId;
        _lastSeen = profile.lastSeen;
        _availability = List<String>.from(profile.availability);
        if (_locationId != null) {
          _locationDetail = await _locationService.getById(_locationId!);
        } else {
          _locationDetail = null;
        }
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _togglePresence(bool value) async {
    setState(() => _isOnline = value);
    try {
      await _presence.setPresence(isOnline: value);
      if (mounted) {
        // Pull latest profile into the AuthProvider cache so coordinators see it
        await context.read<AuthProvider>().refreshProfile();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOnline = !value);
      _showError(e);
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isAvailable = value);
    try {
      await _presence.setPresence(isAvailable: value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAvailable = !value);
      _showError(e);
    }
  }

  Future<void> _setLocation(AppLocation? location) async {
    final previous = _locationDetail;
    setState(() {
      _locationDetail = location;
      _locationId = location?.id;
    });
    try {
      await _presence.setPresence(
        currentLocationId: location?.id,
        latitude: location?.latitude,
        longitude: location?.longitude,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationDetail = previous;
        _locationId = previous?.id;
      });
      _showError(e);
    }
  }

  Future<void> _toggleAvailabilityWindow(String window) async {
    final next = List<String>.from(_availability);
    if (next.contains(window)) {
      next.remove(window);
    } else {
      next.add(window);
    }
    setState(() {
      _availability = next;
      _saving = true;
    });
    try {
      final existing = await _profileService.getProfile();
      await _profileService.upsertProfile(
        fullName: existing?['full_name'] as String? ?? '',
        phone: existing?['phone'] as String? ?? '',
        city: existing?['city'] as String? ?? '',
        skills: existing?['skills'] != null
            ? List<String>.from(existing!['skills'] as List)
            : <String>[],
        availability: next,
        notes: existing?['notes'] as String?,
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  SlideInAnimation(
                    child: _PresenceHero(
                      isOnline: _isOnline,
                      lastSeen: _lastSeen,
                      onToggle: _togglePresence,
                    ),
                  ),
                  const SizedBox(height: 22),
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 80),
                    child: _SectionCard(
                      title: 'Available for new tasks',
                      subtitle:
                          'Support sees this when picking a volunteer for a task.',
                      icon: Icons.notifications_active_outlined,
                      child: Switch.adaptive(
                        value: _isAvailable,
                        activeColor: AppTheme.success,
                        onChanged: _toggleAvailability,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 120),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.place_rounded,
                                    color: AppTheme.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Current location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Pick from the validated list so support can dispatch '
                            'the closest volunteer to an accident.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          LocationPicker(
                            selectedId: _locationId,
                            onChanged: _setLocation,
                            includeNoneOption: true,
                            noneLabel: 'Hide my location',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 160),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.schedule_rounded,
                                    color: AppTheme.accent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Weekly availability windows',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (_saving)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: availabilityOptions.map((a) {
                              final selected = _availability.contains(a);
                              return FilterChip(
                                label: Text(a),
                                selected: selected,
                                selectedColor:
                                    AppTheme.success.withOpacity(0.15),
                                checkmarkColor: AppTheme.success,
                                onSelected: (_) => _toggleAvailabilityWindow(a),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style:
                            const TextStyle(color: AppTheme.error, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _PresenceHero extends StatelessWidget {
  const _PresenceHero({
    required this.isOnline,
    required this.lastSeen,
    required this.onToggle,
  });

  final bool isOnline;
  final DateTime? lastSeen;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppTheme.success : AppTheme.textLight;
    final subtitle = isOnline
        ? 'You are visible as Online. Support can ping you.'
        : lastSeen != null
            ? 'Offline. Last seen ${DateFormat.MMMd().add_jm().format(lastSeen!.toLocal())}.'
            : 'Offline. Toggle to start receiving tasks and calls.';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isOnline
            ? AppTheme.successGradient
            : const LinearGradient(
                colors: [Color(0xFF334155), Color(0xFF475569)],
              ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.92),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isOnline,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.4),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
