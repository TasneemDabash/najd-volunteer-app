import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads voice notes to the `voice-messages` storage bucket and sends them
/// through the support chat RPCs.
class VoiceMessageService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _bucket = 'voice-messages';

  /// Uploads [file] to `voice-messages/<uid>/<timestamp>.<ext>` and returns the
  /// public URL.
  Future<String> uploadVoiceFile(File file) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw Exception('Not authenticated');
    }
    final ext = _detectExtension(file.path);
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final objectPath = '$uid/$name';
    await _client.storage.from(_bucket).upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: _contentTypeForExt(ext),
            upsert: false,
          ),
        );
    return _client.storage.from(_bucket).getPublicUrl(objectPath);
  }

  String _detectExtension(String path) {
    final i = path.lastIndexOf('.');
    if (i == -1 || i == path.length - 1) return 'm4a';
    return path.substring(i + 1).toLowerCase();
  }

  String _contentTypeForExt(String ext) {
    switch (ext) {
      case 'aac':
        return 'audio/aac';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'opus':
        return 'audio/opus';
      case 'webm':
        return 'audio/webm';
      case 'm4a':
      default:
        return 'audio/mp4';
    }
  }

  /// Volunteer → support: send a voice message they recorded.
  Future<void> submitVolunteerVoice({
    required File file,
    required int durationMs,
  }) async {
    final url = await uploadVoiceFile(file);
    await _client.rpc('submit_support_voice_message', params: {
      'p_media_url': url,
      'p_duration_ms': durationMs,
    });
  }

  /// Coordinator → volunteer: reply with a voice message.
  Future<void> replyVolunteerVoice({
    required String volunteerUserId,
    required File file,
    required int durationMs,
  }) async {
    final url = await uploadVoiceFile(file);
    await _client.rpc('support_reply_voice', params: {
      'p_volunteer_id': volunteerUserId,
      'p_media_url': url,
      'p_duration_ms': durationMs,
    });
  }
}
