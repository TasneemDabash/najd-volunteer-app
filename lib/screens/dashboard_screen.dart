import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../l10n/app_strings.dart';
import '../models/task_model.dart';
import '../models/user_role.dart';
import '../navigation/coordinator_shell_intent.dart';
import '../providers/auth_provider.dart';
import '../services/task_service.dart';
import '../services/volunteer_service.dart';
import '../widgets/animations.dart';
import '../widgets/app_card.dart';
import 'tasks/create_task_screen.dart';
import 'tasks/task_list_screen.dart';
import 'tasks/task_publish_requests_screen.dart';
import 'tasks/task_templates_screen.dart';
import 'volunteers/volunteer_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    this.onSwitchTab,
    this.onOpenAdminTools,
    this.showAdminToolsButton = false,
  });

  /// Switch bottom tab when embedded in coordinator shell (admin/support).
  final void Function(int tabIndex)? onSwitchTab;

  final VoidCallback? onOpenAdminTools;
  final bool showAdminToolsButton;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _totalVolunteers = 0;
  int _activeTasks = 0;
  int _completedTasks = 0;
  int _emergencyRequests = 0;
  bool _loading = true;

  late AnimationController _counterController;
  late Animation<double> _counterAnimation;

  final VolunteerService _volunteerService = VolunteerService();
  final TaskService _taskService = TaskService();

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadStats();
    });
  }

  @override
  void dispose() {
    _counterController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final role = Provider.of<AuthProvider>(context, listen: false).role;
      final coordinator = role == UserRole.admin || role == UserRole.support;
      final vs = await _volunteerService.getVolunteersCount(
        coordinatorView: coordinator,
      );
      final active = await _taskService.getActiveTasksCount();
      final completed = await _taskService.getCompletedTasksCount();
      if (mounted) {
        setState(() {
          _totalVolunteers = vs;
          _activeTasks = active;
          _completedTasks = completed;
          _emergencyRequests = 0;
          _loading = false;
        });
        _counterController.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goToTab(int index, {String? skillFilter, TaskStatus? taskStatus}) {
    if (skillFilter != null) {
      CoordinatorShellIntent.setVolunteerSkillFilter(skillFilter);
    }
    if (taskStatus != null) {
      CoordinatorShellIntent.setTaskStatusFilter(taskStatus);
    }
    if (widget.onSwitchTab != null) {
      widget.onSwitchTab!(index);
      return;
    }
    // Standalone fallback (should not happen in shell).
    Widget page;
    switch (index) {
      case CoordinatorTab.volunteers:
        page = VolunteerListScreen(initialSkillFilter: skillFilter);
        break;
      case CoordinatorTab.tasks:
        page = TaskListScreen(initialStatus: taskStatus);
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _loadStats());
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final isAdmin = role == UserRole.admin;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: ShimmerLoading(height: 200)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeInAnimation(
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'لوحة التحكم',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textPrimary,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isAdmin
                                          ? 'مدير — تنسيق المتطوعين والمهام'
                                          : 'فريق الدعم — تنسيق المتطوعين والمهام',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.showAdminToolsButton)
                                _HeaderIconButton(
                                  icon: Icons.admin_panel_settings_outlined,
                                  tooltip: 'أدوات الإدارة',
                                  onTap: widget.onOpenAdminTools,
                                ),
                              _HeaderIconButton(
                                icon: Icons.notifications_outlined,
                                tooltip: 'التنبيهات',
                                onTap: () => _goToTab(CoordinatorTab.alerts),
                              ),
                              const SizedBox(width: 8),
                              _HeaderIconButton(
                                icon: Icons.settings_outlined,
                                tooltip: 'الإعدادات',
                                onTap: () => _goToTab(CoordinatorTab.settings),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 80),
                          child: AnimatedGradientBorder(
                            borderRadius: 24,
                            borderWidth: 3,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            FloatingAnimation(
                                              distance: 4,
                                              child: const Icon(
                                                Icons.favorite,
                                                color: AppTheme.accent,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Expanded(
                                              child: Text(
                                                'نجد للتطوع',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'تنسيق المتطوعين وإدارة المهام بكفاءة',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppTheme.textSecondary,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.volunteer_activism,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FadeInAnimation(
                          delay: const Duration(milliseconds: 120),
                          child: AnimatedBuilder(
                            animation: _counterAnimation,
                            builder: (context, child) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TappableStatCard(
                                          title: 'المتطوعين',
                                          value: (_totalVolunteers *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.people,
                                          gradient: AppTheme.primaryGradient,
                                          onTap: () => _goToTab(
                                            CoordinatorTab.volunteers,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TappableStatCard(
                                          title: 'المهام النشطة',
                                          value: (_activeTasks *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.assignment,
                                          gradient: AppTheme.warningGradient,
                                          onTap: () => _goToTab(
                                            CoordinatorTab.tasks,
                                            taskStatus: TaskStatus.active,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _TappableStatCard(
                                          title: 'المكتملة',
                                          value: (_completedTasks *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.check_circle,
                                          gradient: AppTheme.successGradient,
                                          onTap: () => _goToTab(
                                            CoordinatorTab.tasks,
                                            taskStatus: TaskStatus.completed,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _TappableStatCard(
                                          title: 'طوارئ',
                                          value: (_emergencyRequests *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.warning_amber,
                                          gradient: AppTheme.redGradient,
                                          onTap: () {
                                            if (_emergencyRequests == 0) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'لا توجد بلاغات طوارئ حالياً',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                            _goToTab(CoordinatorTab.alerts);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 28),
                        const SectionHeader(title: 'إجراءات سريعة'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.people_alt_rounded,
                                label: 'تصفح المتطوعين',
                                gradient: AppTheme.primaryGradient,
                                onTap: () => _goToTab(CoordinatorTab.volunteers),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.add_task,
                                label: AppStrings.createTask,
                                gradient: AppTheme.secondaryGradient,
                                onTap: () => _push(const CreateTaskScreen()),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.assignment_outlined,
                                label: 'كل المهام',
                                gradient: AppTheme.cardGradient,
                                onTap: () => _goToTab(CoordinatorTab.tasks),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _QuickActionButton(
                                icon: Icons.notifications_active_outlined,
                                label: 'التنبيهات',
                                gradient: AppTheme.purpleGradient,
                                onTap: () => _goToTab(CoordinatorTab.alerts),
                              ),
                            ),
                          ],
                        ),
                        if (isAdmin || role == UserRole.support) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.library_books_outlined,
                                  label: 'قوالب المهام',
                                  gradient: AppTheme.successGradient,
                                  onTap: () =>
                                      _push(const TaskTemplatesScreen()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.pending_actions_outlined,
                                  label: 'طلبات النشر',
                                  gradient: AppTheme.warningGradient,
                                  onTap: () => _push(
                                    const TaskPublishRequestsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 28),
                        const SectionHeader(title: 'الخدمات'),
                        const SizedBox(height: 12),
                        _ServiceCard(
                          icon: Icons.local_hospital,
                          title: 'المساعدة الطبية',
                          description:
                              'عرض المتطوعين ذوي المهارات الطبية',
                          gradient: AppTheme.redGradient,
                          onTap: () => _goToTab(
                            CoordinatorTab.volunteers,
                            skillFilter: 'طبي',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ServiceCard(
                          icon: Icons.people_alt,
                          title: 'مساعدة المجتمع',
                          description: 'متطوعون للمساعدة العامة واللوجستية',
                          gradient: AppTheme.purpleGradient,
                          onTap: () => _goToTab(
                            CoordinatorTab.volunteers,
                            skillFilter: 'مساعدة عامة',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ServiceCard(
                          icon: Icons.school,
                          title: 'الدعم التعليمي والتقني',
                          description: 'متطوعون بتقني وترجمة وإعلام',
                          gradient: AppTheme.successGradient,
                          onTap: () => _push(
                            const VolunteerListScreen(
                              initialSkillFilter: 'تقني',
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        const SectionHeader(title: 'إدارة'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ActionCard(
                                title: 'المتطوعين',
                                subtitle: 'عرض جميع المتطوعين',
                                icon: Icons.list,
                                iconGradient: AppTheme.primaryGradient,
                                onTap: () =>
                                    _goToTab(CoordinatorTab.volunteers),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ActionCard(
                                title: 'المهام',
                                subtitle: 'عرض جميع المهام',
                                icon: Icons.assignment_turned_in,
                                iconGradient: AppTheme.secondaryGradient,
                                onTap: () => _goToTab(CoordinatorTab.tasks),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppTheme.textSecondary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _TappableStatCard extends StatelessWidget {
  const _TappableStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final int value;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 16),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left,
                  size: 20,
                  color: AppTheme.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
