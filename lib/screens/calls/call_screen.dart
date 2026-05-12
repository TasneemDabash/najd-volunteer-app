import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/theme.dart';
import '../../models/call_session.dart';
import '../../services/call_service.dart';

/// Full-screen call placeholder.
///
/// We don't wire WebRTC yet — instead we render a clean "calling / in-call"
/// experience and keep the `call_sessions` row in sync (ringing → answered →
/// ended) so that:
///   • The other peer sees the state in real time via Realtime.
///   • When a real media SDK (Agora/Twilio/LiveKit) is added, the screen only
///     needs to attach the audio/video tracks using [session.channelName].
class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.session,
    required this.peerName,
    required this.isIncoming,
    this.peerAvatarText,
  });

  final CallSession session;
  final String peerName;
  final String? peerAvatarText;
  final bool isIncoming;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final CallService _service = CallService();
  late CallSession _session;
  RealtimeChannel? _channel;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _muted = false;
  bool _speaker = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _ensurePermissions();
    _channel = _service.subscribeSession(_session.id, (s) {
      if (!mounted) return;
      setState(() => _session = s);
      if (_session.status == CallStatus.answered && _timer == null) {
        _startTimer();
      }
      if (_session.status == CallStatus.ended ||
          _session.status == CallStatus.declined ||
          _session.status == CallStatus.cancelled ||
          _session.status == CallStatus.missed) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) Navigator.maybePop(context);
        });
      }
    });
    if (_session.status == CallStatus.answered) {
      _startTimer();
    }
  }

  Future<void> _ensurePermissions() async {
    await Permission.microphone.request();
    if (_session.callType == CallType.video) {
      await Permission.camera.request();
    }
  }

  void _startTimer() {
    final base = _session.answeredAt ?? DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(base));
    });
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final s = await _service.updateStatus(
        callId: _session.id,
        status: CallStatus.answered,
      );
      if (mounted) {
        setState(() => _session = s);
        _startTimer();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _hangUp({CallStatus? overrideStatus}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final status = overrideStatus ??
        (_session.status == CallStatus.ringing
            ? (widget.isIncoming ? CallStatus.declined : CallStatus.cancelled)
            : CallStatus.ended);
    try {
      await _service.updateStatus(callId: _session.id, status: status);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
    if (mounted) {
      setState(() => _busy = false);
      Navigator.maybePop(context);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  String _format(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    if (h > 0) return '$h:$mm:$ss';
    return '$mm:$ss';
  }

  String get _statusLabel {
    switch (_session.status) {
      case CallStatus.ringing:
        return widget.isIncoming ? 'Incoming call' : 'Calling…';
      case CallStatus.answered:
        return 'Connected · ${_format(_elapsed)}';
      case CallStatus.ended:
        return 'Call ended';
      case CallStatus.declined:
        return 'Call declined';
      case CallStatus.cancelled:
        return 'Call cancelled';
      case CallStatus.missed:
        return 'Missed call';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = _session.callType == CallType.video;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _hangUp();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.expand_more_rounded,
                          color: Colors.white),
                      onPressed: () => _hangUp(),
                    ),
                    const Spacer(),
                    Text(
                      isVideo ? 'Video call' : 'Voice call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _AvatarPulse(
                        text: widget.peerAvatarText ??
                            (widget.peerName.isNotEmpty
                                ? widget.peerName[0].toUpperCase()
                                : '?'),
                        pulsing: _session.status == CallStatus.ringing,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        widget.peerName.isEmpty
                            ? 'Unknown contact'
                            : widget.peerName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (isVideo)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.white70, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Video stream is reserved – wire your WebRTC/Agora '
                                  'SDK using session channel name to enable it.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                child: Column(
                  children: [
                    if (_session.status == CallStatus.answered)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _IconToggle(
                            active: !_muted,
                            iconOn: Icons.mic_rounded,
                            iconOff: Icons.mic_off_rounded,
                            label: _muted ? 'Unmute' : 'Mute',
                            onTap: () => setState(() => _muted = !_muted),
                          ),
                          _IconToggle(
                            active: _speaker,
                            iconOn: Icons.volume_up_rounded,
                            iconOff: Icons.volume_off_rounded,
                            label: _speaker ? 'Speaker' : 'Earpiece',
                            onTap: () => setState(() => _speaker = !_speaker),
                          ),
                          if (isVideo)
                            _IconToggle(
                              active: true,
                              iconOn: Icons.cameraswitch_rounded,
                              iconOff: Icons.cameraswitch_rounded,
                              label: 'Flip',
                              onTap: () {},
                            ),
                        ],
                      ),
                    const SizedBox(height: 18),
                    if (widget.isIncoming &&
                        _session.status == CallStatus.ringing) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _RoundButton(
                            color: AppTheme.error,
                            icon: Icons.call_end_rounded,
                            label: 'Decline',
                            onTap: () => _hangUp(
                                overrideStatus: CallStatus.declined),
                          ),
                          _RoundButton(
                            color: AppTheme.success,
                            icon: Icons.call_rounded,
                            label: 'Accept',
                            onTap: _accept,
                          ),
                        ],
                      ),
                    ] else
                      Center(
                        child: _RoundButton(
                          color: AppTheme.error,
                          icon: Icons.call_end_rounded,
                          label: _session.status == CallStatus.ringing
                              ? 'Cancel'
                              : 'End',
                          onTap: () => _hangUp(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarPulse extends StatefulWidget {
  const _AvatarPulse({required this.text, required this.pulsing});

  final String text;
  final bool pulsing;

  @override
  State<_AvatarPulse> createState() => _AvatarPulseState();
}

class _AvatarPulseState extends State<_AvatarPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = widget.pulsing ? 1 + 0.12 * _controller.value : 1.0;
        final opacity = widget.pulsing ? (1 - _controller.value) : 0.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: 200 * scale,
                height: 200 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.18 * opacity),
                ),
              ),
            child!,
          ],
        );
      },
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 46,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  const _IconToggle({
    required this.active,
    required this.iconOn,
    required this.iconOff,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData iconOn;
  final IconData iconOff;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withOpacity(0.16)
                  : Colors.white.withOpacity(0.05),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
              ),
            ),
            child: Icon(active ? iconOn : iconOff, color: Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
