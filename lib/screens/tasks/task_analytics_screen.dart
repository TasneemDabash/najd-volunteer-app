import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../models/task_model.dart';
import '../../services/task_service.dart';
import '../../widgets/animations.dart';
import 'task_details_screen.dart';

class TaskAnalyticsScreen extends StatefulWidget {
  const TaskAnalyticsScreen({super.key});

  @override
  State<TaskAnalyticsScreen> createState() => _TaskAnalyticsScreenState();
}

class _TaskAnalyticsScreenState extends State<TaskAnalyticsScreen> {
  final TaskService _service = TaskService();
  TaskAnalytics? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final analytics = await _service.getTaskAnalytics();
      if (mounted) setState(() => _analytics = analytics);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: AppTheme.error,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('تحليل المهام'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _analytics == null
              ? const Center(child: Text('لا توجد بيانات'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Overall stats
                        SlideInAnimation(
                          child: _buildOverallStats(),
                        ),
                        const SizedBox(height: 24),

                        // Success rate card
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 100),
                          child: _buildSuccessRateCard(),
                        ),
                        const SizedBox(height: 24),

                        // Skills breakdown
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 200),
                          child: _buildSkillsSection(),
                        ),
                        const SizedBox(height: 24),

                        // Recent tasks
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 300),
                          child: _buildRecentTasksSection(),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildOverallStats() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'إجمالي المهام',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_analytics!.totalTasks}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'مكتملة',
                value: '${_analytics!.completedTasks}',
                icon: Icons.check_circle,
              ),
              _StatItem(
                label: 'نشطة',
                value: '${_analytics!.activeTasks}',
                icon: Icons.play_circle,
              ),
              _StatItem(
                label: 'قيد الانتظار',
                value: '${_analytics!.pendingTasks}',
                icon: Icons.pending,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRateCard() {
    final rate = _analytics!.overallSuccessRate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'نسبة النجاح الإجمالية',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 12,
                    backgroundColor: AppTheme.surfaceLight,
                    valueColor: AlwaysStoppedAnimation(
                      rate >= 70
                          ? AppTheme.success
                          : rate >= 40
                              ? AppTheme.warning
                              : AppTheme.error,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${rate.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: rate >= 70
                      ? AppTheme.success
                      : rate >= 40
                          ? AppTheme.warning
                          : AppTheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: AppTheme.secondary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'تحليل حسب المهارات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._analytics!.skillStats.entries
              .where((e) => e.value.total > 0)
              .map((entry) => _buildSkillRow(entry.key, entry.value)),
          if (_analytics!.skillStats.values.every((s) => s.total == 0))
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد بيانات كافية',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillRow(String skill, SkillStats stats) {
    final colors = {
      'طبي': Colors.red,
      'لوجستي': Colors.blue,
      'قيادة': Colors.orange,
      'ترجمة': Colors.purple,
      'إعلام': Colors.teal,
      'تقني': Colors.indigo,
      'مساعدة عامة': Colors.green,
    };
    final color = colors[skill] ?? AppTheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    skill,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '${stats.completed}/${stats.total} (${stats.successRate.toStringAsFixed(0)}%)',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.successRate / 100,
              minHeight: 8,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTasksSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.history,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'آخر 10 مهام',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_analytics!.recentTasks.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'لا توجد مهام',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(_analytics!.recentTasks.length, (index) {
              final task = _analytics!.recentTasks[index];
              return _RecentTaskItem(
                task: task,
                statusColor: _getStatusColor(task.status),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TaskDetailsScreen(taskId: task.id),
                  ),
                ).then((_) => _load()),
              );
            }),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RecentTaskItem extends StatelessWidget {
  final TaskModel task;
  final Color statusColor;
  final VoidCallback onTap;

  const _RecentTaskItem({
    required this.task,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.surfaceLight,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (task.requiredSkills.isNotEmpty) ...[
                        Text(
                          task.requiredSkills.first,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const Text(
                          ' • ',
                          style: TextStyle(color: AppTheme.textLight),
                        ),
                      ],
                      Text(
                        DateFormat('d MMM').format(task.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.status == TaskStatus.completed
                    ? 'نجاح'
                    : task.status == TaskStatus.active
                        ? 'جارية'
                        : 'انتظار',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
