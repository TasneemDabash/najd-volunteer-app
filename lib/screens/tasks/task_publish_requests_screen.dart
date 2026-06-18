import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_publish_request.dart';
import '../../services/task_publish_request_service.dart';
import '../../widgets/skill_chip.dart';
import 'task_details_screen.dart';

/// Admin/support screen to review volunteer task publish requests.
class TaskPublishRequestsScreen extends StatefulWidget {
  const TaskPublishRequestsScreen({super.key});

  @override
  State<TaskPublishRequestsScreen> createState() =>
      _TaskPublishRequestsScreenState();
}

class _TaskPublishRequestsScreenState extends State<TaskPublishRequestsScreen> {
  final _service = TaskPublishRequestService();
  List<TaskPublishRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getPendingRequests();
    if (mounted) {
      setState(() {
        _requests = list;
        _loading = false;
      });
    }
  }

  Future<void> _approve(TaskPublishRequest req) async {
    try {
      final taskId = await _service.approveRequest(req.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.requestApproved),
            backgroundColor: AppTheme.success,
          ),
        );
        if (taskId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailsScreen(taskId: taskId),
            ),
          );
        }
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix} $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _reject(TaskPublishRequest req) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.reject),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: AppStrings.rejectionReason,
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text(AppStrings.reject),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null) return;

    try {
      await _service.rejectRequest(req.id, reason: reason.isEmpty ? null : reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.requestRejected)),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix} $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.publishRequests),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _requests.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(
                          child: Text(
                            'لا توجد طلبات نشر قيد الانتظار',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _requests.length,
                      itemBuilder: (context, i) {
                        final r = _requests[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.title,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (r.userName != null || r.userEmail != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'من: ${r.userName ?? r.userEmail}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                if (r.description.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(r.description),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  '${AppStrings.location}: ${r.location.isEmpty ? AppStrings.notSet : r.location}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                if (r.scheduledDate != null)
                                  Text(
                                    '${AppStrings.scheduled}: ${DateFormat.yMMMMd('ar').add_jm().format(r.scheduledDate!)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                if (r.requiredSkills.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  SkillSection(
                                    skills: r.requiredSkills,
                                    compact: true,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _reject(r),
                                        child: const Text(AppStrings.reject),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton(
                                        onPressed: () => _approve(r),
                                        child: const Text(AppStrings.approve),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
