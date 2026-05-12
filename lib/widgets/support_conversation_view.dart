import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/theme.dart';
import '../services/support_message_service.dart';
import '../services/voice_message_service.dart';
import 'voice_message_widgets.dart';

/// Shared volunteer / coordinator support thread UI with Realtime inserts.
class SupportConversationView extends StatefulWidget {
  const SupportConversationView({
    super.key,
    required this.threadVolunteerId,
    required this.isCoordinator,
  });

  /// Conversation key: always the volunteer’s user id.
  final String threadVolunteerId;
  final bool isCoordinator;

  @override
  State<SupportConversationView> createState() =>
      _SupportConversationViewState();
}

class _SupportConversationViewState extends State<SupportConversationView> {
  final _service = SupportMessageService();
  final _voice = VoiceMessageService();
  final _scroll = ScrollController();
  final _input = TextEditingController();
  final List<SupportChatMessage> _messages = [];
  RealtimeChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  bool _voiceUploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _load();
    _subscribe();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final list = widget.isCoordinator
          ? await _service.listThreadMessages(widget.threadVolunteerId)
          : await _service.listMyChatMessages();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _subscribe() {
    final client = Supabase.instance.client;
    _channel?.unsubscribe();
    _channel = client
        .channel(
            'support_chat_${widget.threadVolunteerId}_${client.auth.currentUser?.id ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_volunteer_id',
            value: widget.threadVolunteerId,
          ),
          callback: (payload) {
            final raw = payload.newRecord;
            if (raw.isEmpty || !mounted) return;
            try {
              final msg = SupportChatMessage.fromJson(
                Map<String, dynamic>.from(raw),
              );
              if (_messages.any((m) => m.id == msg.id)) return;
              setState(() {
                _messages.add(msg);
              });
              _scrollToEnd();
            } catch (_) {}
          },
        )
        .subscribe();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      if (widget.isCoordinator) {
        await _service.replyToVolunteer(widget.threadVolunteerId, text);
      } else {
        await _service.submitMessage(text);
      }
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(File file, int durationMs) async {
    setState(() => _voiceUploading = true);
    try {
      if (widget.isCoordinator) {
        await _voice.replyVolunteerVoice(
          volunteerUserId: widget.threadVolunteerId,
          file: file,
          durationMs: durationMs,
        );
      } else {
        await _voice.submitVolunteerVoice(file: file, durationMs: durationMs);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice send failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _voiceUploading = false);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scroll.dispose();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = Supabase.instance.client.auth.currentUser?.id ?? '';

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      widget.isCoordinator
                          ? 'No messages in this thread yet.'
                          : 'Say hello — support will see your message in Alerts and can reply here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.9),
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final m = _messages[index];
                    final mine = m.senderId == me;
                    return _Bubble(
                      message: m,
                      alignEnd: mine,
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: widget.isCoordinator
                          ? 'Reply to volunteer…'
                          : 'Message support…',
                      filled: true,
                      fillColor: AppTheme.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                VoiceRecorderButton(
                  disabled: _sending || _voiceUploading,
                  onRecorded: _sendVoice,
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: _sending ? null : _send,
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: _sending || _voiceUploading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.alignEnd,
  });

  final SupportChatMessage message;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.MMMd().add_jm().format(message.createdAt);
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: alignEnd ? AppTheme.primaryGradient : null,
          color: alignEnd ? null : AppTheme.surfaceLight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(alignEnd ? 18 : 4),
            bottomRight: Radius.circular(alignEnd ? 4 : 18),
          ),
          boxShadow: alignEnd
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (message.isVoice)
              VoiceMessagePlayer(
                url: message.mediaUrl!,
                durationMs: message.durationMs,
                tint: alignEnd ? Colors.white : AppTheme.primary,
                onTint: alignEnd ? AppTheme.primary : Colors.white,
              )
            else
              Text(
                message.body,
                style: TextStyle(
                  color: alignEnd ? Colors.white : AppTheme.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: alignEnd
                    ? Colors.white.withOpacity(0.85)
                    : AppTheme.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
