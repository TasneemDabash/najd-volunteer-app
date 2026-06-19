import '../models/task_model.dart';

/// One-shot navigation hints when switching coordinator bottom tabs from the dashboard.
class CoordinatorShellIntent {
  CoordinatorShellIntent._();

  static String? pendingVolunteerSkillFilter;
  static TaskStatus? pendingTaskStatus;

  static String? consumeVolunteerSkillFilter() {
    final value = pendingVolunteerSkillFilter;
    pendingVolunteerSkillFilter = null;
    return value;
  }

  static TaskStatus? consumeTaskStatusFilter() {
    final value = pendingTaskStatus;
    pendingTaskStatus = null;
    return value;
  }

  static void setVolunteerSkillFilter(String? skill) {
    pendingVolunteerSkillFilter = skill;
  }

  static void setTaskStatusFilter(TaskStatus? status) {
    pendingTaskStatus = status;
  }
}

/// Bottom tab indices for coordinator shells (admin / support).
abstract final class CoordinatorTab {
  static const int overview = 0;
  static const int volunteers = 1;
  static const int tasks = 2;
  static const int messages = 3;
  static const int notifications = 4;
  static const int settings = 5;

  /// Legacy alias — use [notifications].
  static const int alerts = notifications;
}
