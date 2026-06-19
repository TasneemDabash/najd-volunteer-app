import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/theme.dart';
import '../services/support_message_service.dart';
import '../widgets/animations.dart';
import 'coordinator_support_thread_screen.dart';

/// Coordinator inbox — volunteer support chats only (separate from notifications).
class SupportInboxScreen extends StatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  State<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends State<SupportInboxScreen> {
  final _service = SupportMessageService();
  List<SupportThreadRow> _threads = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.listForCoordinator();
      if (mounted) setState(() => _threads = list);
    } catch (_) {
      if (mounted) setState(() => _threads = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<SupportThreadRow> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _threads;
    return _threads.where((t) {
      return t.displaySender.toLowerCase().contains(q) ||
          t.senderEmail.toLowerCase().contains(q) ||
          t.body.toLowerCase().contains(q);
    }).toList();
  }

  void _openThread(SupportThreadRow row) {
    if (row.fromUserId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoordinatorSupportThreadScreen(
          volunteerUserId: row.fromUserId,
          volunteerDisplayName: row.displaySender,
          volunteerEmail: row.senderEmail.isEmpty ? null : row.senderEmail,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final threads = _filtered;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('المحادثات'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الرسالة…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: _load,
                    child: threads.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.sizeOf(context).height * 0.35,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 72,
                                        color:
                                            AppTheme.textLight.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _search.isEmpty
                                            ? 'لا توجد محادثات بعد'
                                            : 'لا توجد نتائج',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      if (_search.isEmpty) ...[
                                        const SizedBox(height: 8),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 32),
                                          child: Text(
                                            'عندما يتواصل المتطوعون مع الدعم، ستظهر محادثاتهم هنا.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: AppTheme.textLight,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: threads.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final row = threads[index];
                              return SlideInAnimation(
                                delay: Duration(
                                  milliseconds: 30 * index.clamp(0, 10),
                                ),
                                child: _ThreadTile(
                                  row: row,
                                  onTap: row.fromUserId.isEmpty
                                      ? null
                                      : () => _openThread(row),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.row, this.onTap});

  final SupportThreadRow row;
  final VoidCallback? onTap;

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} ي';
    return DateFormat.MMMd('ar').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.secondary.withOpacity(0.15),
                child: Text(
                  row.displaySender.isNotEmpty
                      ? row.displaySender[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.displaySender,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(row.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ),
                    if (row.senderEmail.isNotEmpty &&
                        row.senderEmail != row.displaySender)
                      Text(
                        row.senderEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      row.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_left,
                color: onTap != null ? AppTheme.primary : AppTheme.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
