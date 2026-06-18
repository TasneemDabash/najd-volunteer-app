import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_publish_request.dart';
import '../../services/task_publish_request_service.dart';
import 'create_task_screen.dart';

/// Volunteer screen to submit task publish requests and view history.
class RequestTaskPublishScreen extends StatefulWidget {
  const RequestTaskPublishScreen({super.key});

  @override
  State<RequestTaskPublishScreen> createState() =>
      _RequestTaskPublishScreenState();
}

class _RequestTaskPublishScreenState extends State<RequestTaskPublishScreen> {
  final _service = TaskPublishRequestService();
  List<TaskPublishRequest> _requests = [];
  bool _hasPending = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final requests = await _service.getMyRequests();
    final pending = await _service.hasPendingRequest();
    if (mounted) {
      setState(() {
        _requests = requests;
        _hasPending = pending;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.requestPublishTask),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: _hasPending
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateTaskScreen(publishOnly: true),
                ),
              ).then((_) => _load()),
              icon: const Icon(Icons.add_rounded),
              label: const Text(AppStrings.requestPublishTask),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_hasPending)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.warning.withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              color: AppTheme.warning),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.pendingPublishRequest,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    AppStrings.myPublishRequests,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (_requests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'لم ترسل أي طلبات نشر بعد',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    )
                  else
                    ..._requests.map((r) {
                      Color statusColor;
                      switch (r.status) {
                        case 'approved':
                          statusColor = AppTheme.success;
                          break;
                        case 'rejected':
                          statusColor = AppTheme.error;
                          break;
                        default:
                          statusColor = AppTheme.warning;
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(r.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.statusDisplayName,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  )),
                              Text(
                                DateFormat.yMMMd('ar').format(r.createdAt),
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (r.rejectionReason != null &&
                                  r.rejectionReason!.isNotEmpty)
                                Text(
                                  '${AppStrings.rejectionReason}: ${r.rejectionReason}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.error,
                                  ),
                                ),
                            ],
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
