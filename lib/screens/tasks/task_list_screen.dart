import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_service.dart';
import '../../widgets/animations.dart';
import 'create_task_screen.dart';
import 'task_details_screen.dart';
import 'task_publish_requests_screen.dart';
import 'task_templates_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, this.initialStatus});

  final TaskStatus? initialStatus;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskService _service = TaskService();
  List<TaskModel> _tasks = [];
  TaskStatus? _filterStatus;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.getTasks(status: _filterStatus);
      if (mounted) setState(() => _tasks = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix} $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppTheme.success;
      case TaskStatus.active:
        return AppTheme.warning;
      default:
        return AppTheme.textLight;
    }
  }

  LinearGradient _getStatusGradient(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppTheme.successGradient;
      case TaskStatus.active:
        return AppTheme.warningGradient;
      default:
        return const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final isCoordinator =
        role == UserRole.admin || role == UserRole.support;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.tasks),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isCoordinator)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                final page = v == 'templates'
                    ? const TaskTemplatesScreen()
                    : const TaskPublishRequestsScreen();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'templates',
                  child: Text(AppStrings.manageTemplates),
                ),
                PopupMenuItem(
                  value: 'requests',
                  child: Text(AppStrings.publishRequests),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              ).then((_) => _load()),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern filter chips
          SlideInAnimation(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _ModernFilterChip(
                    label: AppStrings.all,
                    selected: _filterStatus == null,
                    onTap: () => setState(() {
                      _filterStatus = null;
                      _load();
                    }),
                  ),
                  ...TaskStatus.values.map((s) => _ModernFilterChip(
                        label: s.displayName,
                        selected: _filterStatus == s,
                        color: _getStatusColor(s),
                        gradient: _getStatusGradient(s),
                        onTap: () => setState(() {
                          _filterStatus = s;
                          _load();
                        }),
                      )),
                ],
              ),
            ),
          ),

          // Task list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                size: 48,
                                color: AppTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مهام',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return SlideInAnimation(
                              delay: Duration(milliseconds: index * 50),
                              child: _ModernTaskCard(
                                task: task,
                                statusColor: _getStatusColor(task.status),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TaskDetailsScreen(taskId: task.id),
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

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final LinearGradient? gradient;
  final VoidCallback onTap;

  const _ModernFilterChip({
    required this.label,
    required this.selected,
    this.color,
    this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? (gradient ?? AppTheme.primaryGradient) : null,
            color: selected ? null : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (color ?? AppTheme.primary).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : AppTheme.cardShadow,
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

class _ModernTaskCard extends StatefulWidget {
  final TaskModel task;
  final Color statusColor;
  final VoidCallback onTap;

  const _ModernTaskCard({
    required this.task,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_ModernTaskCard> createState() => _ModernTaskCardState();
}

class _ModernTaskCardState extends State<_ModernTaskCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        transform: Matrix4.identity()
          ..translate(0.0, _isHovered ? -2.0 : 0.0),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isHovered ? AppTheme.cardShadowHover : AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.task.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Location and date
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.task.location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat.MMMd().format(widget.task.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Skills
                  if (widget.task.requiredSkills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.task.requiredSkills.take(3).map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppTheme.secondaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
