import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/volunteer.dart';
import '../../services/user_profile_service.dart';

/// Shown once after signup — collects skills & availability only.
/// Name, phone, and city were already captured during registration.
class CompleteVolunteerProfileScreen extends StatefulWidget {
  const CompleteVolunteerProfileScreen({super.key});

  @override
  State<CompleteVolunteerProfileScreen> createState() =>
      _CompleteVolunteerProfileScreenState();
}

class _CompleteVolunteerProfileScreenState
    extends State<CompleteVolunteerProfileScreen> {
  final _profileService = UserProfileService();
  final _skills = <String>[];
  final _availability = <String>[];
  bool _loading = false;
  bool _loadingProfile = true;
  String _displayName = '';
  String _displayCity = '';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final map = await _profileService.getProfile();
    if (mounted) {
      setState(() {
        _displayName = map?['full_name'] as String? ?? '';
        _displayCity = map?['city'] as String? ?? '';
        if (map?['skills'] != null) {
          _skills.addAll(List<String>.from(map!['skills'] as List));
        }
        if (map?['availability'] != null) {
          _availability
              .addAll(List<String>.from(map!['availability'] as List));
        }
        _loadingProfile = false;
      });
    }
  }

  Future<void> _save({bool skip = false}) async {
    if (!skip && (_skills.isEmpty || _availability.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('اختر مهارة واحدة على الأقل ووقتاً للتوفر'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final map = await _profileService.getProfile();
      await _profileService.upsertProfile(
        fullName: map?['full_name'] as String? ?? _displayName,
        phone: map?['phone'] as String? ?? '',
        city: map?['city'] as String? ?? _displayCity,
        skills: _skills,
        availability: _availability,
        notes: map?['notes'] as String?,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('أكمل ملفك التطوعي'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'خطوة أخيرة',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'مرحباً ${_displayName.isNotEmpty ? _displayName : ''}! '
              'اختر مهاراتك وأوقات توفرك لمساعدتنا في مطابقتك مع المهام المناسبة.',
              style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            if (_displayCity.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _displayCity,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 28),
            const Text(
              'المهارات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: skillOptions.map((s) {
                final selected = _skills.contains(s);
                return FilterChip(
                  label: Text(s),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _skills.add(s);
                      } else {
                        _skills.remove(s);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'التوفر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _availability.add(a);
                      } else {
                        _availability.remove(a);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : () => _save(),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ والمتابعة'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loading ? null : () => _save(skip: true),
              child: const Text('تخطي الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
