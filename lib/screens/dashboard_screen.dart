import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/user_role.dart';
import '../providers/auth_provider.dart';
import '../services/volunteer_service.dart';
import '../services/task_service.dart';
import '../widgets/animations.dart';
import '../widgets/app_card.dart';
import 'volunteers/volunteer_list_screen.dart';
import 'tasks/task_list_screen.dart';
import 'tasks/create_task_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

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

  final VolunteerService _volunteerService = VolunteerService();
  final TaskService _taskService = TaskService();

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
      setState(() {
        _totalVolunteers = vs;
        _activeTasks = active;
        _completedTasks = completed;
        _emergencyRequests = 0;
        _loading = false;
      });
      _counterController.forward(from: 0);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Center(child: ShimmerLoading(height: 200)),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        SlideInAnimation(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
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
                                      'فريق الدعم — تنسيق المتطوعين والمهام',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _IconButton(
                                    icon: Icons.notifications_outlined,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _IconButton(
                                    icon: Icons.settings_outlined,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const SettingsScreen()),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Hero welcome card with animated gradient border
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 100),
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
                                            Expanded(
                                              child: Text(
                                                'نجد للتطوع',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
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

                        // Stats grid with counter animations
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 200),
                          child: AnimatedBuilder(
                            animation: _counterAnimation,
                            builder: (context, child) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AnimatedStatCard(
                                          title: 'المتطوعين',
                                          value: (_totalVolunteers *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.people,
                                          gradient: AppTheme.primaryGradient,
                                          trend: '+12%',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _AnimatedStatCard(
                                          title: 'المهام النشطة',
                                          value: (_activeTasks *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.assignment,
                                          gradient: AppTheme.warningGradient,
                                          trend: '+5%',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _AnimatedStatCard(
                                          title: 'المكتملة',
                                          value: (_completedTasks *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.check_circle,
                                          gradient: AppTheme.successGradient,
                                          trend: '+28%',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _AnimatedStatCard(
                                          title: 'طوارئ',
                                          value: (_emergencyRequests *
                                                  _counterAnimation.value)
                                              .toInt(),
                                          icon: Icons.warning_amber,
                                          gradient: AppTheme.redGradient,
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

                        // Quick actions
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 300),
                          child: const SectionHeader(title: 'إجراءات سريعة'),
                        ),

                        const SizedBox(height: 12),

                        SlideInAnimation(
                          delay: const Duration(milliseconds: 350),
                          child: Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.people_alt_rounded,
                                  label: 'تصفح المتطوعين',
                                  gradient: AppTheme.primaryGradient,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const VolunteerListScreen(),
                                    ),
                                  ).then((_) => _loadStats()),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.add_task,
                                  label: 'إنشاء مهمة',
                                  gradient: AppTheme.secondaryGradient,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateTaskScreen()),
                                  ).then((_) => _loadStats()),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Services section
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 400),
                          child: const SectionHeader(title: 'الخدمات'),
                        ),

                        const SizedBox(height: 12),

                        // Service cards
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 450),
                          child: _ServiceCard(
                            icon: Icons.local_hospital,
                            title: 'المساعدة الطبية',
                            description: 'خدمات الرعاية الصحية والدعم الطبي',
                            gradient: AppTheme.redGradient,
                            onTap: () {},
                          ),
                        ),

                        const SizedBox(height: 12),

                        SlideInAnimation(
                          delay: const Duration(milliseconds: 500),
                          child: _ServiceCard(
                            icon: Icons.people_alt,
                            title: 'مساعدة المجتمع',
                            description: 'دعم أفراد المجتمع المحتاجين',
                            gradient: AppTheme.purpleGradient,
                            onTap: () {},
                          ),
                        ),

                        const SizedBox(height: 12),

                        SlideInAnimation(
                          delay: const Duration(milliseconds: 550),
                          child: _ServiceCard(
                            icon: Icons.school,
                            title: 'الدعم التعليمي',
                            description: 'التدريس والمساعدة التعليمية',
                            gradient: AppTheme.successGradient,
                            onTap: () {},
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Navigation cards
                        SlideInAnimation(
                          delay: const Duration(milliseconds: 600),
                          child: const SectionHeader(title: 'إدارة'),
                        ),

                        const SizedBox(height: 12),

                        SlideInAnimation(
                          delay: const Duration(milliseconds: 650),
                          child: Row(
                            children: [
                              Expanded(
                                child: ActionCard(
                                  title: 'المتطوعين',
                                  subtitle: 'عرض جميع المتطوعين',
                                  icon: Icons.list,
                                  iconGradient: AppTheme.primaryGradient,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const VolunteerListScreen()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ActionCard(
                                  title: 'المهام',
                                  subtitle: 'عرض جميع المهام',
                                  icon: Icons.assignment_turned_in,
                                  iconGradient: AppTheme.secondaryGradient,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const TaskListScreen()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Icon(icon, color: AppTheme.textSecondary, size: 22),
        ),
      ),
    );
  }
}

class _AnimatedStatCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final LinearGradient gradient;
  final String? trend;

  const _AnimatedStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.trending_up,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 2),
                      Text(
                        trend!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.gradient.colors.first.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: widget.gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textLight,
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
