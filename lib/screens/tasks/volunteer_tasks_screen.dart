import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/skill_chip.dart';
import 'request_task_publish_screen.dart';
import 'task_details_screen.dart';

/// Volunteer-side replacement of the old placeholder tasks tab.
///
/// Loads tasks assigned to the current user via `list_my_assigned_tasks` RPC,
/// supports basic status filtering and lets the volunteer mark a task active
/// or completed from the details screen.
class VolunteerTasksScreen extends StatefulWidget {
  const VolunteerTasksScreen({super.key});

  @override
  State<VolunteerTasksScreen> createState() => _VolunteerTasksScreenState();
}

class _VolunteerTasksScreenState extends State<VolunteerTasksScreen> {
  final TaskService _service = TaskService();
  List<TaskModel> _assignedTasks = [];
  List<TaskModel> _openTasks = [];
  Set<String> _openTaskIds = {};
  TaskStatus? _filter;
  bool _loading = true;
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
      final assigned = await _service.getMyAssignedTasks();
      final open = await _service.getOpenTasks();
      if (!mounted) return;
      setState(() {
        _assignedTasks = assigned;
        _openTasks = open;
        _openTaskIds = open.map((t) => t.id).toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<TaskModel> get _tasks {
    // Combine assigned and open tasks, removing duplicates
    final combined = <String, TaskModel>{};
    for (final t in _assignedTasks) {
      combined[t.id] = t;
    }
    for (final t in _openTasks) {
      combined[t.id] = t;
    }
    return combined.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Color _statusColor(TaskStatus s) {
    switch (s) {
      case TaskStatus.completed:
        return AppTheme.success;
      case TaskStatus.active:
        return AppTheme.warning;
      case TaskStatus.pending:
        return AppTheme.textLight;
    }
  }

  List<TaskModel> get _visibleTasks {
    if (_filter == null) return _tasks;
    return _tasks.where((t) => t.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.myTasks),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: AppStrings.requestPublishTask,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const RequestTaskPublishScreen(),
              ),
            ),
            icon: const Icon(Icons.send_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _FilterChipPill(
                  label: AppStrings.all,
                  selected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                ...TaskStatus.values.map(
                  (s) => _FilterChipPill(
                    label: s.displayName,
                    color: _statusColor(s),
                    selected: _filter == s,
                    onTap: () => setState(() => _filter = s),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(error: _error!, onRetry: _load)
                    : _visibleTasks.isEmpty
                        ? _EmptyState(filter: _filter)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _visibleTasks.length,
                              itemBuilder: (context, index) {
                                final t = _visibleTasks[index];
                                final isOpen = _openTaskIds.contains(t.id);
                                return SlideInAnimation(
                                  delay: Duration(milliseconds: index * 40),
                                  child: _MyTaskCard(
                                    task: t,
                                    statusColor: _statusColor(t.status),
                                    isOpenToAll: isOpen,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TaskDetailsScreen(
                                          taskId: t.id,
                                        ),
                                      ),
                                    ).then((_) => _load()),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _MyTaskCard extends StatelessWidget {
  const _MyTaskCard({
    required this.task,
    required this.statusColor,
    required this.onTap,
    this.isOpenToAll = false,
  });

  final TaskModel task;
  final Color statusColor;
  final VoidCallback onTap;
  final bool isOpenToAll;

  @override
  Widget build(BuildContext context) {
    final loc = task.displayLocation;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        task.status.displayName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isOpenToAll) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.public_rounded,
                            size: 14, color: AppTheme.primary),
                        SizedBox(width: 4),
                        Text(
                          AppStrings.openToAll,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.place_rounded,
                        size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        loc.isEmpty ? AppStrings.notSet : loc,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.event_rounded,
                        size: 14, color: AppTheme.textLight),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat.MMMd().add_jm().format(task.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (task.requiredSkills.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SkillSection(skills: task.requiredSkills, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipPill extends StatelessWidget {
  const _FilterChipPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? c : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final TaskStatus? filter;

  @override
  Widget build(BuildContext context) {
    final msg = filter == null
        ? 'لا توجد مهام معيّنة لك أو مفتوحة للجميع.\nتحقق لاحقاً أو تواصل مع الدعم.'
        : 'لا توجد مهام ${filter!.displayName} حالياً.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined,
                  size: 56, color: AppTheme.secondary),
            ),
            const SizedBox(height: 18),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 48),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
          ],
        ),
      ),
    );
  }
}
