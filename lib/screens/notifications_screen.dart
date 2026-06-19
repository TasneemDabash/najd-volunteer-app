import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../models/app_notification.dart';
import '../models/user_role.dart';
import '../navigation/notification_navigation.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../widgets/notification_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.onSwitchTab,
  });

  /// When embedded in admin/support shell, switch bottom tabs (e.g. tasks).
  final void Function(int tabIndex)? onSwitchTab;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<AppNotification> _all = [];
  NotificationFilter _filter = NotificationFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await _service.getNotifications();
      if (mounted) setState(() => _all = list);
    } catch (_) {
      if (mounted) setState(() => _all = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<AppNotification> get _visible {
    final role = context.read<AuthProvider>().role;
    final coordinator =
        role == UserRole.admin || role == UserRole.support;

    return _all.where((n) {
      if (coordinator && n.type == 'support_message') return false;

      final pres = NotificationPresentation.forNotification(n);
      return pres.matchesFilter(_filter);
    }).toList();
  }

  int get _unreadCount => _visible.where((n) => !n.read).length;

  Future<void> _markAllRead() async {
    await _service.markAllAsRead();
    await _load();
  }

  Future<void> _onTapNotification(AppNotification n) async {
    final role = context.read<AuthProvider>().role;
    final destination = NotificationDestination.resolve(n, role: role);

    if (destination == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يوجد صفحة مرتبطة بهذا الإشعار'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await navigateToNotificationDestination(
      context,
      destination,
      onSwitchTab: widget.onSwitchTab,
    );

    if (!n.read) {
      try {
        await _service.markAsRead(n.id);
      } catch (_) {}
      if (mounted) {
        setState(() {
          final i = _all.indexWhere((x) => x.id == n.id);
          if (i >= 0) {
            _all[i] = AppNotification(
              id: n.id,
              title: n.title,
              body: n.body,
              type: n.type,
              taskId: n.taskId,
              createdAt: n.createdAt,
              read: true,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = groupNotificationsByDate(_visible);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإشعارات'),
            if (_unreadCount > 0)
              Text(
                '$_unreadCount غير مقروء',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_all.any((n) => !n.read))
            TextButton(
              onPressed: _markAllRead,
              child: const Text('قراءة الكل'),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NotificationFilterBar(
                  selected: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: grouped.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.4,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.notifications_none_rounded,
                                        size: 72,
                                        color:
                                            AppTheme.textLight.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _filter == NotificationFilter.all
                                            ? 'لا توجد إشعارات'
                                            : 'لا توجد إشعارات في هذا التصنيف',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'اضغط على إشعار للانتقال إلى الصفحة ذات الصلة',
                                        style: TextStyle(
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                            children: [
                              for (final entry in grouped.entries) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, bottom: 10),
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                                ...entry.value.map(
                                  (n) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: NotificationListTile(
                                      notification: n,
                                      onTap: () => _onTapNotification(n),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
