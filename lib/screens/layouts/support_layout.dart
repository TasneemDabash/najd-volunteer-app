import 'package:flutter/material.dart';

import '../../navigation/coordinator_shell_intent.dart';
import '../../widgets/modern_bottom_nav.dart';
import '../dashboard_screen.dart';
import '../notifications_screen.dart';
import '../settings_screen.dart';
import '../tasks/task_list_screen.dart';
import '../volunteers/volunteer_list_screen.dart';
import 'coordinator_shell_tabs.dart';

/// Shell for [UserRole.support]: coordinator tabs (overview, volunteers, tasks, alerts, settings).
class SupportLayout extends StatefulWidget {
  const SupportLayout({super.key});

  @override
  State<SupportLayout> createState() => _SupportLayoutState();
}

class _SupportLayoutState extends State<SupportLayout> {
  int _index = CoordinatorTab.overview;
  Widget _volunteersPage =
      const VolunteerListScreen(key: ValueKey('tab_volunteers'));
  Widget _tasksPage = const TaskListScreen(key: ValueKey('tab_tasks'));

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
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(
              key: const ValueKey('tab_overview'),
              onSwitchTab: _switchTab,
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
