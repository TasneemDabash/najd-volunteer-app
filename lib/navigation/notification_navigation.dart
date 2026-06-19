import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/user_role.dart';
import '../screens/contact_support_screen.dart';
import '../screens/support_inbox_screen.dart';
import '../screens/tasks/task_details_screen.dart';
import '../screens/tasks/task_publish_requests_screen.dart';
import 'coordinator_shell_intent.dart';

/// Resolves where a notification should take the user.
class NotificationDestination {
  const NotificationDestination._(this.kind, {this.taskId});

  final _NotificationDestinationKind kind;
  final String? taskId;

  static NotificationDestination? resolve(
    AppNotification n, {
    required UserRole role,
  }) {
    final type = (n.type ?? '').trim().toLowerCase();
    final title = n.title.trim();
    final body = n.body.trim();
    final coordinator =
        role == UserRole.admin || role == UserRole.support;

    final isPublishRequest = type == 'task_publish_request' ||
        title.contains('طلب نشر') ||
        (body.contains('يرجى المراجعة') && body.contains('متطوع'));

    if (isPublishRequest && coordinator) {
      return const NotificationDestination._(
        _NotificationDestinationKind.publishRequests,
      );
    }

    if (type == 'support_message' ||
        (title.contains('رسالة') && title.contains('دعم'))) {
      if (coordinator) {
        return const NotificationDestination._(
          _NotificationDestinationKind.supportInbox,
        );
      }
      return const NotificationDestination._(
        _NotificationDestinationKind.contactSupport,
      );
    }

    if (n.taskId != null && n.taskId!.isNotEmpty) {
      return NotificationDestination._(
        _NotificationDestinationKind.taskDetails,
        taskId: n.taskId,
      );
    }

    if (type.contains('task') ||
        type == 'task_assignment' ||
        type == 'task_status' ||
        type == 'emergency') {
      // Task-related but no id — open task list area for coordinators.
      if (coordinator) {
        return const NotificationDestination._(
          _NotificationDestinationKind.tasksTab,
        );
      }
    }

    return null;
  }
}

enum _NotificationDestinationKind {
  publishRequests,
  supportInbox,
  contactSupport,
  taskDetails,
  tasksTab,
}

/// Opens the screen for [destination]. Returns true if navigation happened.
Future<bool> navigateToNotificationDestination(
  BuildContext context,
  NotificationDestination destination, {
  void Function(int tabIndex)? onSwitchTab,
}) {
  final nav = Navigator.of(context, rootNavigator: true);

  switch (destination.kind) {
    case _NotificationDestinationKind.publishRequests:
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const TaskPublishRequestsScreen(),
        ),
      );
      return Future.value(true);
    case _NotificationDestinationKind.supportInbox:
      onSwitchTab?.call(CoordinatorTab.messages);
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const SupportInboxScreen(),
        ),
      );
      return Future.value(true);
    case _NotificationDestinationKind.contactSupport:
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const ContactSupportScreen(),
        ),
      );
      return Future.value(true);
    case _NotificationDestinationKind.taskDetails:
      final id = destination.taskId;
      if (id == null || id.isEmpty) return Future.value(false);
      nav.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => TaskDetailsScreen(taskId: id),
        ),
      );
      return Future.value(true);
    case _NotificationDestinationKind.tasksTab:
      onSwitchTab?.call(CoordinatorTab.tasks);
      return Future.value(true);
  }
}
