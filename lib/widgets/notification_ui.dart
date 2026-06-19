import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../models/app_notification.dart';

enum NotificationFilter { all, tasks, requests, support }

extension NotificationFilterLabel on NotificationFilter {
  String get label => switch (this) {
        NotificationFilter.all => 'الكل',
        NotificationFilter.tasks => 'مهام',
        NotificationFilter.requests => 'طلبات',
        NotificationFilter.support => 'دعم',
      };
}

/// High-contrast filter row for the notifications screen.
class NotificationFilterBar extends StatelessWidget {
  const NotificationFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final NotificationFilter selected;
  final ValueChanged<NotificationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: NotificationFilter.values.map((f) {
          final isSelected = selected == f;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelected(f),
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : const Color(0xFFCBD5E1),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        f.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class NotificationPresentation {
  const NotificationPresentation({
    required this.icon,
    required this.gradient,
    required this.category,
  });

  final IconData icon;
  final LinearGradient gradient;
  final NotificationFilter category;

  static NotificationPresentation forNotification(AppNotification n) {
    final type = (n.type ?? '').toLowerCase();
    final title = n.title;

    if (type == 'task_publish_request' || title.contains('طلب نشر')) {
      return const NotificationPresentation(
        icon: Icons.pending_actions_rounded,
        gradient: AppTheme.warningGradient,
        category: NotificationFilter.requests,
      );
    }
    if (type == 'support_message') {
      return const NotificationPresentation(
        icon: Icons.support_agent_rounded,
        gradient: AppTheme.pinkGradient,
        category: NotificationFilter.support,
      );
    }
    if (type == 'emergency') {
      return const NotificationPresentation(
        icon: Icons.warning_amber_rounded,
        gradient: AppTheme.redGradient,
        category: NotificationFilter.tasks,
      );
    }
    if (type == 'task_assignment') {
      return const NotificationPresentation(
        icon: Icons.assignment_ind_rounded,
        gradient: AppTheme.primaryGradient,
        category: NotificationFilter.tasks,
      );
    }
    if (type == 'task_status') {
      return const NotificationPresentation(
        icon: Icons.sync_rounded,
        gradient: AppTheme.secondaryGradient,
        category: NotificationFilter.tasks,
      );
    }
    return const NotificationPresentation(
      icon: Icons.notifications_rounded,
      gradient: AppTheme.purpleGradient,
      category: NotificationFilter.all,
    );
  }

  bool matchesFilter(NotificationFilter filter) {
    if (filter == NotificationFilter.all) return true;
    return category == filter;
  }
}

String notificationTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
  return DateFormat.yMMMd('ar').add_jm().format(dt);
}

String notificationDateGroupKey(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  if (day == today) return 'اليوم';
  if (day == today.subtract(const Duration(days: 1))) return 'أمس';
  return 'سابقاً';
}

Map<String, List<AppNotification>> groupNotificationsByDate(
  List<AppNotification> items,
) {
  final map = <String, List<AppNotification>>{};
  for (final n in items) {
    final key = notificationDateGroupKey(n.createdAt);
    map.putIfAbsent(key, () => []).add(n);
  }
  const order = ['اليوم', 'أمس', 'سابقاً'];
  return Map.fromEntries(
    order.where(map.containsKey).map((k) => MapEntry(k, map[k]!)),
  );
}

class NotificationListTile extends StatelessWidget {
  const NotificationListTile({
    super.key,
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pres = NotificationPresentation.forNotification(notification);
    final unread = !notification.read;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: unread
                ? AppTheme.primary.withOpacity(0.04)
                : AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? AppTheme.primary.withOpacity(0.22)
                  : const Color(0xFFE8ECF0),
            ),
            boxShadow: unread ? AppTheme.cardShadowHover : AppTheme.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: pres.gradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(pres.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 9,
                            height: 9,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notificationTimeAgo(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_left,
                color: AppTheme.textLight.withOpacity(0.8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
