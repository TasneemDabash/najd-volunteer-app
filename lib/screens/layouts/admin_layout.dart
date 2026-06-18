import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/user_profile.dart';
import '../../models/user_role.dart';
import '../../services/account_service.dart';
import '../../services/task_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/app_card.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../../navigation/coordinator_shell_intent.dart';
import '../dashboard_screen.dart';
import '../notifications_screen.dart';
import '../settings_screen.dart';
import '../tasks/task_list_screen.dart';
import '../admin/role_requests_screen.dart';
import '../tasks/task_publish_requests_screen.dart';
import '../tasks/task_templates_screen.dart';
import '../volunteers/volunteer_list_screen.dart';
import 'coordinator_shell_tabs.dart';

/// Shell for [UserRole.admin]. Same coordinator tabs as support (overview, volunteers,
/// tasks, alerts, settings), plus a drawer (shield FAB, top-left) for user/role tools.
class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  int _index = CoordinatorTab.overview;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Widget _volunteersPage =
      const VolunteerListScreen(key: ValueKey('tab_volunteers'));
  Widget _tasksPage = const TaskListScreen(key: ValueKey('tab_tasks'));

  void _openAdminDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _switchTab(int index) {
    final skill = CoordinatorShellIntent.consumeVolunteerSkillFilter();
    final taskStatus = CoordinatorShellIntent.consumeTaskStatusFilter();
    if (skill != null) {
      _volunteersPage = VolunteerListScreen(
        key: ValueKey('tab_volunteers_$skill'),
        initialSkillFilter: skill,
      );
    }
    if (taskStatus != null) {
      _tasksPage = TaskListScreen(
        key: ValueKey('tab_tasks_${taskStatus.name}'),
        initialStatus: taskStatus,
      );
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: _AdminToolsDrawer(onClose: () => Navigator.of(context).pop()),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'admin_tools_menu',
        elevation: 3,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        tooltip: 'أدوات الإدارة',
        onPressed: _openAdminDrawer,
        child: const Icon(Icons.admin_panel_settings_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              key: const ValueKey('tab_overview'),
              onSwitchTab: _switchTab,
              onOpenAdminTools: _openAdminDrawer,
              showAdminToolsButton: true,
            ),
            _volunteersPage,
            _tasksPage,
            const NotificationsScreen(key: ValueKey('tab_alerts')),
            const SettingsScreen(key: ValueKey('tab_settings')),
          ],
        ),
      ),
      bottomNavigationBar: ModernBottomNav(
        currentIndex: _index,
        onTap: _switchTab,
        items: kCoordinatorShellNavItems,
      ),
    );
  }
}

class _AdminToolsDrawer extends StatelessWidget {
  const _AdminToolsDrawer({required this.onClose});

  final VoidCallback onClose;

  void _push(BuildContext context, Widget page) {
    onClose();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(gradient: AppTheme.purpleGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'الإدارة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'المستخدمون والأدوار وأدوات المنصة',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.library_books_outlined, color: AppTheme.primary),
              title: const Text('قوالب المهام'),
              subtitle: const Text('مهام دائمة ومقترحة'),
              onTap: () => _push(context, const TaskTemplatesScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions_outlined, color: AppTheme.primary),
              title: const Text('طلبات نشر المهام'),
              subtitle: const Text('مراجعة طلبات المتطوعين'),
              onTap: () => _push(context, const TaskPublishRequestsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.upgrade_outlined, color: AppTheme.primary),
              title: const Text('طلبات ترقية الأدوار'),
              subtitle: const Text('قبول أو رفض طلبات الدعم/الإدارة'),
              onTap: () => _push(context, const AdminRoleRequestsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined, color: AppTheme.primary),
              title: const Text('إدارة المستخدمين'),
              subtitle: const Text('الأدوار وحالة الحساب'),
              onTap: () => _push(context, const _UserManagementScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined, color: AppTheme.primary),
              title: const Text('الأدوار والسياسات'),
              subtitle: const Text('كيف يعمل الوصول'),
              onTap: () => _push(context, const _RoleManagementScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.support_agent_outlined, color: AppTheme.primary),
              title: const Text('فريق الدعم'),
              subtitle: const Text('المنسقون والحسابات'),
              onTap: () => _push(context, const _SupportTeamManagementScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined, color: AppTheme.primary),
              title: const Text('النظام'),
              subtitle: const Text('ملاحظات المنصة'),
              onTap: () => _push(context, const _SystemSettingsScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined, color: AppTheme.primary),
              title: const Text('التقارير'),
              subtitle: const Text('إحصائيات الاستخدام'),
              onTap: () => _push(context, const _ReportsScreen()),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.close, color: AppTheme.textSecondary.withOpacity(0.8)),
              title: const Text('إغلاق'),
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserManagementScreen extends StatefulWidget {
  const _UserManagementScreen();

  @override
  State<_UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<_UserManagementScreen> {
  final AccountService _accountService = AccountService();
  List<UserProfile> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _accountService.fetchAllProfilesForManagement();
      if (mounted) setState(() => _users = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString(),
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _changeRole(UserProfile user, UserRole role) async {
    try {
      final updated = await _accountService.updateRoleAsAdmin(
        userId: user.id,
        role: role,
      );
      if (!mounted) return;
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated role for ${user.fullName.isNotEmpty ? user.fullName : user.email}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update role'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _setStatus(UserProfile user, String status) async {
    try {
      final updated = await _accountService.updateStatusAsAdmin(
        userId: user.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated status for ${user.fullName.isNotEmpty ? user.fullName : user.email}'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to update status'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  String _initials(UserProfile u) {
    final name = u.fullName.trim();
    if (name.isEmpty) {
      final e = u.email;
      return e.isNotEmpty ? e[0].toUpperCase() : '?';
    }
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Color _roleAccent(UserRole r) {
    switch (r) {
      case UserRole.admin:
        return const Color(0xFF8B5CF6);
      case UserRole.support:
        return AppTheme.secondary;
      case UserRole.volunteer:
        return AppTheme.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('User management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  SlideInAnimation(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B5CF6).withOpacity(0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Administrator',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Assign Support or Admin roles here. Volunteers see the volunteer home.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white70,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_users.length, (index) {
                    final u = _users[index];
                    final accent = _roleAccent(u.role);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SlideInAnimation(
                        delay: Duration(milliseconds: 60 * index.clamp(0, 8)),
                        child: AppCard(
                          elevated: true,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: accent.withOpacity(0.15),
                                    child: Text(
                                      _initials(u),
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          u.fullName.isNotEmpty
                                              ? u.fullName
                                              : u.email,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          u.email,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          u.city.isNotEmpty
                                              ? u.city
                                              : 'No city',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _LabeledDropdown<UserRole>(
                                    label: 'Role',
                                    value: u.role,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      _changeRole(u, value);
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                        value: UserRole.volunteer,
                                        child: Text('Volunteer'),
                                      ),
                                      DropdownMenuItem(
                                        value: UserRole.support,
                                        child: Text('Support'),
                                      ),
                                      DropdownMenuItem(
                                        value: UserRole.admin,
                                        child: Text('Admin'),
                                      ),
                                    ],
                                  ),
                                  _LabeledDropdown<String>(
                                    label: 'Status',
                                    value: u.status,
                                    onChanged: (value) {
                                      if (value == null) return;
                                      _setStatus(u, value);
                                    },
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'active',
                                        child: Text('Active'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'inactive',
                                        child: Text('Inactive'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'deactivated',
                                        child: Text('Deactivated'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final String label;
  final T value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textLight,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              onChanged: onChanged,
              items: items,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoleManagementScreen extends StatelessWidget {
  const _RoleManagementScreen();

  @override
  Widget build(BuildContext context) {
    return _AdminInfoScaffold(
      title: 'Roles',
      heroSubtitle: 'Who can do what in Najd',
      heroIcon: Icons.admin_panel_settings_rounded,
      heroGradient: AppTheme.purpleGradient,
      sections: const [
        _InfoBlock(
          title: 'How roles work',
          body:
              'Volunteers use the volunteer home. Support sees coordination tools (dashboard, volunteers, tasks). Admins see this private area and can change anyone’s role.',
        ),
        _InfoBlock(
          title: 'Changes',
          body:
              'Open the shield menu (floating button) → User management to promote someone to Support or Admin, or back to Volunteer. They should sign out and sign in again to refresh the app shell.',
        ),
      ],
    );
  }
}

class _SupportTeamManagementScreen extends StatelessWidget {
  const _SupportTeamManagementScreen();

  @override
  Widget build(BuildContext context) {
    return _AdminInfoScaffold(
      title: 'Support team',
      heroSubtitle: 'Who helps volunteers day to day',
      heroIcon: Icons.support_agent_rounded,
      heroGradient: AppTheme.secondaryGradient,
      sections: const [
        _InfoBlock(
          title: 'Accounts',
          body:
              'Each support person should have their own login. Assign the Support role from User management (shield menu).',
        ),
        _InfoBlock(
          title: 'Coordination',
          body:
              'Support accounts use the same Supabase data as volunteers but land on the support dashboard instead of the volunteer home.',
        ),
      ],
    );
  }
}

class _SystemSettingsScreen extends StatelessWidget {
  const _SystemSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return _AdminInfoScaffold(
      title: 'System',
      heroSubtitle: 'Platform-level controls',
      heroIcon: Icons.tune_rounded,
      heroGradient: AppTheme.primaryGradient,
      sections: const [
        _InfoBlock(
          title: 'Configuration',
          body:
              'Backend settings (Supabase URL, keys, email) stay in your project config and Supabase dashboard — not in this screen yet.',
        ),
        _InfoBlock(
          title: 'Future',
          body:
              'This tab is reserved for feature flags, maintenance messages, and other operator controls.',
        ),
      ],
    );
  }
}

class _ReportsScreen extends StatefulWidget {
  const _ReportsScreen();

  @override
  State<_ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<_ReportsScreen> {
  final _volunteerService = VolunteerService();
  final _taskService = TaskService();
  final _accountService = AccountService();

  int _volunteers = 0;
  int _activeTasks = 0;
  int _completedTasks = 0;
  int _users = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final v = await _volunteerService.getVolunteersCount(coordinatorView: true);
      final active = await _taskService.getActiveTasksCount();
      final completed = await _taskService.getCompletedTasksCount();
      final users = await _accountService.fetchAllProfilesForManagement();
      if (mounted) {
        setState(() {
          _volunteers = v;
          _activeTasks = active;
          _completedTasks = completed;
          _users = users.length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('التقارير'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _ReportStatCard(
                    label: 'إجمالي الحسابات',
                    value: '$_users',
                    icon: Icons.groups_outlined,
                    gradient: AppTheme.purpleGradient,
                  ),
                  const SizedBox(height: 12),
                  _ReportStatCard(
                    label: 'المتطوعون',
                    value: '$_volunteers',
                    icon: Icons.people_outline,
                    gradient: AppTheme.primaryGradient,
                  ),
                  const SizedBox(height: 12),
                  _ReportStatCard(
                    label: 'المهام النشطة',
                    value: '$_activeTasks',
                    icon: Icons.assignment_outlined,
                    gradient: AppTheme.warningGradient,
                  ),
                  const SizedBox(height: 12),
                  _ReportStatCard(
                    label: 'المهام المكتملة',
                    value: '$_completedTasks',
                    icon: Icons.check_circle_outline,
                    gradient: AppTheme.successGradient,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'يتم تحديث الأرقام من قاعدة البيانات مباشرة. اسحب للأسفل للتحديث.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportStatCard extends StatelessWidget {
  const _ReportStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
  });

  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock {
  const _InfoBlock({required this.title, required this.body});

  final String title;
  final String body;
}

class _AdminInfoScaffold extends StatelessWidget {
  const _AdminInfoScaffold({
    required this.title,
    required this.heroSubtitle,
    required this.heroIcon,
    required this.heroGradient,
    required this.sections,
  });

  final String title;
  final String heroSubtitle;
  final IconData heroIcon;
  final LinearGradient heroGradient;
  final List<_InfoBlock> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SlideInAnimation(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: heroGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: heroGradient.colors.first.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(heroIcon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      heroSubtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < sections.length; i++) ...[
            SlideInAnimation(
              delay: Duration(milliseconds: 100 * (i + 1)),
              child: AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sections[i].title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      sections[i].body,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i < sections.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
