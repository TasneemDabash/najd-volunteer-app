import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/skill_chip.dart';
import '../volunteers/volunteer_profile_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailsScreen({super.key, required this.taskId});

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  final TaskService _service = TaskService();
  final VolunteerService _volunteerService = VolunteerService();
  TaskModel? _task;
  List<Volunteer> _assigned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final task = await _service.getTaskById(widget.taskId);
      List<Volunteer> assigned = [];
      if (task != null) {
        assigned = await _service.getAssignedVolunteers(task.id);
      }
      if (mounted) {
        setState(() {
          _task = task;
          _assigned = assigned;
        });
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateStatus(TaskStatus status) async {
    if (_task == null) return;
    try {
      await _service.updateTaskStatus(_task!.id, status);
      if (mounted) setState(() => _task = _task!.copyWith(status: status));
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _deleteTask() async {
    if (_task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteTask),
        content: const Text(AppStrings.deleteTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteTask(_task!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.taskDeleted),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _openAssignSheet({required UserRole role}) async {
    if (_task == null) return;
    final originLat = _task!.latitude;
    final originLon = _task!.longitude;
    final all = await _volunteerService.getVolunteers(
      coordinatorDirectory: true,
      originLat: originLat,
      originLon: originLon,
    );
    final volunteers = all
        .where((v) =>
            (v.appRole?.toLowerCase() ?? 'volunteer') == 'volunteer' &&
            (v.status?.toLowerCase() ?? 'active') == 'active')
        .toList();
    if (!mounted) return;

    final currentlyAssigned = _assigned.map((v) => v.id).toSet();
    final selected = Set<String>.from(currentlyAssigned);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              minChildSize: 0.4,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.textLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.person_add_alt_1_rounded,
                              color: AppTheme.primary),
                          const SizedBox(width: 8),
                          const Text(
                            AppStrings.assignVolunteers,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (originLat != null && originLon != null)
                            const Chip(
                              label: Text(AppStrings.closestFirst,
                                  style: TextStyle(fontSize: 11)),
                              backgroundColor: Color(0xFFE0F2FE),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اختر المتطوعين للتعيين. سيصلهم إشعار داخل التطبيق.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: volunteers.isEmpty
                            ? const Center(
                                child: Text(AppStrings.noVolunteersAvailable),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: volunteers.length,
                                itemBuilder: (context, index) {
                                  final v = volunteers[index];
                                  final isSelected = selected.contains(v.id);
                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setSheetState(() {
                                        if (val == true) {
                                          selected.add(v.id);
                                        } else {
                                          selected.remove(v.id);
                                        }
                                      });
                                    },
                                    title: Text(v.fullName.isNotEmpty
                                        ? v.fullName
                                        : v.email),
                                    subtitle: Wrap(
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      spacing: 6,
                                      children: [
                                        Text(v.currentLocationName ?? v.city,
                                            style: const TextStyle(
                                                fontSize: 12)),
                                        if (v.distanceKm != null) ...[
                                          const Text('·',
                                              style: TextStyle(fontSize: 12)),
                                          Text(
                                            '${v.distanceKm!.toStringAsFixed(1)} ${AppStrings.km}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (v.isOnline) ...[
                                          const Text('·',
                                              style: TextStyle(fontSize: 12)),
                                          const Text(
                                            AppStrings.online,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.success,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (!v.isAvailable) ...[
                                          const Text('·',
                                              style: TextStyle(fontSize: 12)),
                                          const Text(
                                            'مشغول',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.warning,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    secondary: CircleAvatar(
                                      backgroundColor:
                                          AppTheme.secondary.withOpacity(0.15),
                                      child: Text(
                                        v.fullName.isNotEmpty
                                            ? v.fullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppTheme.secondary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(sheetCtx),
                                child: const Text(AppStrings.cancel),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () async {
                                  try {
                                    await _service.assignVolunteers(
                                      _task!.id,
                                      selected.toList(),
                                    );
                                    if (sheetCtx.mounted) {
                                      Navigator.pop(sheetCtx);
                                    }
                                    if (mounted) {
                                      await _load();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(AppStrings.assignmentUpdated),
                                          backgroundColor: AppTheme.success,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) _showError(e);
                                  }
                                },
                                icon: const Icon(Icons.check_rounded),
                                label: Text(
                                  '${AppStrings.save} (${selected.length})',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${AppStrings.errorPrefix} $e'),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.taskDetails)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.taskDetails)),
        body: const Center(child: Text(AppStrings.taskNotFound)),
      );
    }
    final task = _task!;
    final role = context.watch<AuthProvider>().role;
    final isCoordinator = role == UserRole.admin || role == UserRole.support;
    final statusColor = _statusColor(task.status);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.taskDetails),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (task.status != TaskStatus.completed)
            PopupMenuButton<TaskStatus>(
              tooltip: 'Update status',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: _updateStatus,
              itemBuilder: (context) => [
                if (task.status != TaskStatus.active)
                  const PopupMenuItem(
                    value: TaskStatus.active,
                    child: ListTile(
                      leading: Icon(Icons.play_arrow_rounded,
                          color: AppTheme.warning),
                      title: Text(AppStrings.markActive),
                    ),
                  ),
                const PopupMenuItem(
                  value: TaskStatus.completed,
                  child: ListTile(
                    leading: Icon(Icons.check_circle_rounded,
                        color: AppTheme.success),
                    title: Text(AppStrings.markCompleted),
                  ),
                ),
                if (isCoordinator && task.status != TaskStatus.pending)
                  const PopupMenuItem(
                    value: TaskStatus.pending,
                    child: ListTile(
                      leading: Icon(Icons.refresh, color: AppTheme.textLight),
                      title: Text(AppStrings.markPending),
                    ),
                  ),
              ],
            ),
          if (isCoordinator && task.status == TaskStatus.completed)
            IconButton(
              onPressed: _deleteTask,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: AppStrings.deleteTask,
              color: AppTheme.error,
            ),
        ],
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
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            task.status.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        task.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _MetaRow(
                      icon: Icons.place_rounded,
                      label: AppStrings.location,
                      value: task.displayLocation.isEmpty
                          ? AppStrings.notSet
                          : task.displayLocation,
                    ),
                    _MetaRow(
                      icon: Icons.event_rounded,
                      label: AppStrings.scheduled,
                      value: DateFormat.yMMMMd('ar').add_jm().format(task.date),
                    ),
                    if (task.latitude != null && task.longitude != null)
                      _MetaRow(
                        icon: Icons.gps_fixed_rounded,
                        label: AppStrings.coordinates,
                        value:
                            '${task.latitude!.toStringAsFixed(4)}, ${task.longitude!.toStringAsFixed(4)}',
                      ),
                    if (task.requiredSkills.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SkillSection(
                        label: AppStrings.requiredSkills,
                        skills: task.requiredSkills,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppStrings.assignedVolunteers} (${_assigned.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                if (isCoordinator)
                  TextButton.icon(
                    onPressed: () => _openAssignSheet(role: role),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(_assigned.isEmpty ? AppStrings.assign : AppStrings.edit),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_assigned.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: const Text(
                  AppStrings.noVolunteersAssigned,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              )
            else
              ..._assigned.map(
                (v) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.secondary.withOpacity(0.15),
                      child: Text(
                        v.fullName.isNotEmpty
                            ? v.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(v.fullName.isNotEmpty ? v.fullName : v.email),
                    subtitle: Row(
                      children: [
                        if (v.isOnline) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(AppStrings.online,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              )),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            '${v.phone} · ${v.currentLocationName ?? v.city}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            VolunteerProfileScreen(volunteerId: v.id),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textLight),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
