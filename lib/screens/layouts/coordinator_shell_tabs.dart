import 'package:flutter/material.dart';

import '../../models/task_model.dart';
import '../../navigation/coordinator_shell_intent.dart';
import '../../widgets/modern_bottom_nav.dart';

/// Bottom tabs shared by [SupportLayout] and [AdminLayout].
const List<ModernBottomNavItem> kCoordinatorShellNavItems = [
  ModernBottomNavItem(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'نظرة عامة',
  ),
  ModernBottomNavItem(
    icon: Icons.people_outline,
    activeIcon: Icons.people,
    label: 'المتطوعين',
  ),
  ModernBottomNavItem(
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    label: 'المهام',
  ),
  ModernBottomNavItem(
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    label: 'المحادثات',
  ),
  ModernBottomNavItem(
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    label: 'الإشعارات',
  ),
  ModernBottomNavItem(
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'الإعدادات',
  ),
];

/// Applies optional filters then switches coordinator tabs from the dashboard.
void coordinatorSwitchTab(
  void Function(int tabIndex)? onSwitchTab,
  int tabIndex, {
  String? volunteerSkillFilter,
  TaskStatus? taskStatus,
}) {
  if (volunteerSkillFilter != null) {
    CoordinatorShellIntent.setVolunteerSkillFilter(volunteerSkillFilter);
  }
  if (taskStatus != null) {
    CoordinatorShellIntent.setTaskStatusFilter(taskStatus);
  }
  onSwitchTab?.call(tabIndex);
}
