import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call_session.dart';
import '../services/call_service.dart';
import '../screens/calls/call_screen.dart';

/// Wraps a widget tree and listens for incoming `call_sessions` rows targeting
/// the current user. When one arrives, it pushes the [CallScreen] full-screen.
class IncomingCallListener extends StatefulWidget {
  const IncomingCallListener({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<IncomingCallListener> {
  final CallService _service = CallService();
  RealtimeChannel? _channel;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe());
  }

  void _subscribe() {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    _channel?.unsubscribe();
    _channel = _service.subscribeIncoming(_handleIncoming);
  }

  Future<String> _peerName(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email')
          .eq('id', userId)
          .maybeSingle();
      final name = (row?['full_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) return name;
      return (row?['email'] as String?) ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  Future<void> _handleIncoming(CallSession session) async {
    if (_showing) return;
    if (!mounted) return;
    _showing = true;
    final name = await _peerName(session.callerId);
    if (!mounted) {
      _showing = false;
      return;
    }
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          session: session,
          peerName: name,
          isIncoming: true,
        ),
        fullscreenDialog: true,
      ),
    );
    _showing = false;
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
