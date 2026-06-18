import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_template.dart';
import '../../models/volunteer.dart';
import '../../services/task_template_service.dart';

/// Admin/support screen to manage permanent and suggested task templates.
class TaskTemplatesScreen extends StatefulWidget {
  const TaskTemplatesScreen({super.key});

  @override
  State<TaskTemplatesScreen> createState() => _TaskTemplatesScreenState();
}

class _TaskTemplatesScreenState extends State<TaskTemplatesScreen> {
  final _service = TaskTemplateService();
  List<TaskTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getAllTemplates();
    if (mounted) {
      setState(() {
        _templates = list;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor([TaskTemplate? existing]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TemplateEditorSheet(
        template: existing,
        onSave: (t) async {
          if (existing == null) {
            await _service.createTemplate(t);
          } else {
            await _service.updateTemplate(t);
          }
        },
      ),
    );
    if (saved == true) {
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.templateSaved)),
        );
      }
    }
  }

  Future<void> _delete(TaskTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القالب'),
        content: Text('هل تريد حذف «${t.title}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteTemplate(t.id);
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.templateDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.manageTemplates),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.addTemplate),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _templates.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'لا توجد قوالب بعد. أضف مهام دائمة أو مقترحة.',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 88),
                      itemCount: _templates.length,
                      itemBuilder: (context, i) {
                        final t = _templates[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(t.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (t.description.isNotEmpty)
                                  Text(t.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  '${t.isPermanent ? AppStrings.templateKindPermanent : AppStrings.templateKindSuggested} • ${AppStrings.usageCount}: ${t.usageCount}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _openEditor(t);
                                } else if (v == 'delete') {
                                  _delete(t);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Text(AppStrings.edit),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text(AppStrings.delete),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _TemplateEditorSheet extends StatefulWidget {
  const _TemplateEditorSheet({this.template, required this.onSave});

  final TaskTemplate? template;
  final Future<void> Function(TaskTemplate) onSave;

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _kind;
  final _skills = <String>[];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _title = TextEditingController(text: t?.title ?? '');
    _description = TextEditingController(text: t?.description ?? '');
    _kind = t?.kind ?? 'suggested';
    if (t != null) _skills.addAll(t.requiredSkills);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.template == null
                      ? AppStrings.addTemplate
                      : AppStrings.edit,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: AppStrings.templateTitle,
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? AppStrings.required_ : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: AppStrings.description,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _kind,
                  decoration: const InputDecoration(labelText: 'نوع القالب'),
                  items: const [
                    DropdownMenuItem(
                      value: 'permanent',
                      child: Text(AppStrings.templateKindPermanent),
                    ),
                    DropdownMenuItem(
                      value: 'suggested',
                      child: Text(AppStrings.templateKindSuggested),
                    ),
                  ],
                  onChanged: (v) => setState(() => _kind = v ?? 'suggested'),
                ),
                const SizedBox(height: 12),
                const Text(AppStrings.requiredSkills,
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
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
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (_skills.isEmpty) return;
                          setState(() => _saving = true);
                          final base = widget.template;
                          final t = TaskTemplate(
                            id: base?.id ?? '',
                            title: _title.text.trim(),
                            description: _description.text.trim(),
                            requiredSkills: List.from(_skills),
                            kind: _kind,
                            usageCount: base?.usageCount ?? 0,
                            sortOrder: base?.sortOrder ?? 0,
                            isActive: base?.isActive ?? true,
                            createdAt: base?.createdAt ?? DateTime.now(),
                          );
                          await widget.onSave(t);
                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                  child: Text(_saving ? '...' : AppStrings.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
