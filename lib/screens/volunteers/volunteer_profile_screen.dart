import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/call_session.dart';
import '../../models/volunteer.dart';
import '../../services/call_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/support_conversation_view.dart';
import '../calls/call_screen.dart';

class VolunteerProfileScreen extends StatefulWidget {
  final String volunteerId;

  const VolunteerProfileScreen({super.key, required this.volunteerId});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final VolunteerService _service = VolunteerService();
  final CallService _calls = CallService();
  Volunteer? _volunteer;
  bool _loading = true;
  bool _startingCall = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await _service.getVolunteerById(widget.volunteerId);
      if (mounted) setState(() => _volunteer = v);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _dialPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _startCall(CallType type) async {
    if (_volunteer == null || _startingCall) return;
    setState(() => _startingCall = true);
    try {
      final session = await _calls.startCall(
        calleeId: _volunteer!.id,
        type: type,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            session: session,
            peerName: _volunteer!.fullName.isNotEmpty
                ? _volunteer!.fullName
                : _volunteer!.email,
            isIncoming: false,
          ),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start call: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _startingCall = false);
    }
  }

  Future<void> _openChat() async {
    if (_volunteer == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(_volunteer!.fullName.isNotEmpty
                ? _volunteer!.fullName
                : 'Chat'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: SupportConversationView(
            threadVolunteerId: _volunteer!.id,
            isCoordinator: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_volunteer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Volunteer not found')),
      );
    }
    final v = _volunteer!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            SlideInAnimation(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: AppTheme.cardShadowHover,
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            v.fullName.isNotEmpty
                                ? v.fullName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (v.isOnline)
                          Positioned(
                            right: 0,
                            bottom: 4,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      v.fullName.isNotEmpty ? v.fullName : v.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (v.appRole != null && v.appRole!.isNotEmpty)
                          v.appRole!,
                        if (v.currentLocationName != null)
                          v.currentLocationName!
                        else if (v.city.isNotEmpty)
                          v.city,
                        if (v.isAvailable) 'Available' else 'Busy',
                      ].join(' · '),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.88),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionPill(
                          icon: Icons.call_rounded,
                          label: 'Voice',
                          onTap: () => _startCall(CallType.voice),
                          loading: _startingCall,
                        ),
                        _ActionPill(
                          icon: Icons.videocam_rounded,
                          label: 'Video',
                          onTap: () => _startCall(CallType.video),
                          loading: _startingCall,
                        ),
                        _ActionPill(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Chat',
                          onTap: _openChat,
                        ),
                        _ActionPill(
                          icon: Icons.dialpad_rounded,
                          label: 'Dial',
                          onTap: v.phone.isEmpty
                              ? null
                              : () => _dialPhone(v.phone),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _InfoTile(
              icon: Icons.phone_rounded,
              label: 'Phone',
              value: v.phone.isEmpty ? 'Not provided' : v.phone,
            ),
            _InfoTile(
              icon: Icons.email_rounded,
              label: 'Email',
              value: v.email.isEmpty ? 'Not provided' : v.email,
            ),
            _InfoTile(
              icon: Icons.place_rounded,
              label: 'Current location',
              value: v.currentLocationName ??
                  (v.city.isEmpty ? 'Not set' : v.city),
              trailing: v.distanceKm != null
                  ? Text('${v.distanceKm!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ))
                  : null,
            ),
            if (v.lastSeen != null)
              _InfoTile(
                icon: Icons.history_rounded,
                label: 'Last seen',
                value:
                    DateFormat.yMMMd().add_jm().format(v.lastSeen!.toLocal()),
              ),
            if (v.skills.isNotEmpty)
              _ChipsTile(
                icon: Icons.work_outline_rounded,
                label: 'Skills',
                items: v.skills,
                color: AppTheme.primary,
              ),
            if (v.availability.isNotEmpty)
              _ChipsTile(
                icon: Icons.schedule_rounded,
                label: 'Availability',
                items: v.availability,
                color: AppTheme.success,
              ),
            if (v.notes != null && v.notes!.isNotEmpty)
              _InfoTile(
                icon: Icons.note_alt_outlined,
                label: 'Notes',
                value: v.notes!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ChipsTile extends StatelessWidget {
  const _ChipsTile({
    required this.icon,
    required this.label,
    required this.items,
    required this.color,
  });

  final IconData icon;
  final String label;
  final List<String> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
