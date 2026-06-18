import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task_template.dart';

class TaskTemplateService {
  final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'task_templates';

  Future<List<TaskTemplate>> getActiveTemplates() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .order('usage_count', ascending: false);
      return (response as List)
          .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TaskTemplate>> getAllTemplates() async {
    try {
      final response = await _client
          .from(_table)
          .select()
          .order('kind')
          .order('sort_order')
          .order('usage_count', ascending: false);
      return (response as List)
          .map((e) => TaskTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<TaskTemplate> createTemplate(TaskTemplate template) async {
    final userId = _client.auth.currentUser?.id;
    final response = await _client
        .from(_table)
        .insert({
          ...template.toJson(),
          if (userId != null) 'created_by': userId,
          if (userId != null) 'updated_by': userId,
        })
        .select()
        .single();
    return TaskTemplate.fromJson(response);
  }

  Future<TaskTemplate> updateTemplate(TaskTemplate template) async {
    final userId = _client.auth.currentUser?.id;
    final response = await _client
        .from(_table)
        .update({
          ...template.toJson(),
          if (userId != null) 'updated_by': userId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', template.id)
        .select()
        .single();
    return TaskTemplate.fromJson(response);
  }

  Future<void> deleteTemplate(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  Future<void> recordUsage(String templateId) async {
    try {
      await _client.rpc('increment_task_template_usage',
          params: {'p_template_id': templateId});
    } catch (_) {
      final row = await _client
          .from(_table)
          .select('usage_count')
          .eq('id', templateId)
          .maybeSingle();
      if (row != null) {
        final count = (row['usage_count'] as int? ?? 0) + 1;
        await _client
            .from(_table)
            .update({'usage_count': count})
            .eq('id', templateId);
      }
    }
  }
}
