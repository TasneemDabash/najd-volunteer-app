import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/role_request_service.dart';

class RequestRoleScreen extends StatefulWidget {
  const RequestRoleScreen({super.key});

  @override
  State<RequestRoleScreen> createState() => _RequestRoleScreenState();
}

class _RequestRoleScreenState extends State<RequestRoleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _roleRequestService = RoleRequestService();

  String _selectedRole = 'support';
  bool _isLoading = false;
  bool _isSubmitting = false;
  List<RoleRequest> _myRequests = [];
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadMyRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadMyRequests() async {
    setState(() => _isLoading = true);
    try {
      _myRequests = await _roleRequestService.getMyRequests();
    } catch (e) {
      // Ignore - table might not exist yet
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
      _success = null;
    });

    try {
      await _roleRequestService.createRequest(
        requestedRole: _selectedRole,
        reason: _reasonController.text.trim(),
      );

      setState(() {
        _success = 'تم إرسال طلبك بنجاح. سيتم مراجعته من قبل الإدارة.';
        _reasonController.clear();
      });

      _loadMyRequests();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _cancelRequest(String requestId) async {
    try {
      await _roleRequestService.cancelRequest(requestId);
      _loadMyRequests();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الطلب')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPendingRequest =
        _myRequests.any((r) => r.status == 'pending');

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب صلاحيات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.info.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.info),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'يمكنك طلب صلاحيات إضافية كمنسق أو دعم فني. سيتم مراجعة طلبك من قبل الإدارة.',
                            style: TextStyle(color: AppTheme.info),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Previous requests
                  if (_myRequests.isNotEmpty) ...[
                    const Text(
                      'طلباتي السابقة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._myRequests.map((request) => _buildRequestCard(request)),
                    const SizedBox(height: 24),
                  ],

                  // New request form
                  if (!hasPendingRequest) ...[
                    const Text(
                      'طلب جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role selection
                          const Text(
                            'الصلاحية المطلوبة',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildRoleOption(
                            value: 'coordinator',
                            title: 'منسق',
                            description: 'يمكنه إدارة المهام والمتطوعين',
                            icon: Icons.groups_outlined,
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            value: 'support',
                            title: 'دعم فني',
                            description: 'يمكنه الرد على استفسارات المتطوعين',
                            icon: Icons.support_agent_outlined,
                          ),
                          const SizedBox(height: 8),
                          _buildRoleOption(
                            value: 'admin',
                            title: 'مدير',
                            description: 'صلاحيات كاملة للنظام',
                            icon: Icons.admin_panel_settings_outlined,
                          ),

                          const SizedBox(height: 20),

                          // Reason field
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'سبب الطلب',
                              hintText: 'اشرح لماذا تحتاج هذه الصلاحية...',
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: AppTheme.surfaceLight,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'الرجاء كتابة سبب الطلب';
                              }
                              if (v.trim().length < 10) {
                                return 'الرجاء كتابة شرح أكثر تفصيلاً';
                              }
                              return null;
                            },
                          ),

                          // Error message
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: AppTheme.error, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style:
                                          const TextStyle(color: AppTheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Success message
                          if (_success != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline,
                                      color: AppTheme.success, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _success!,
                                      style: const TextStyle(
                                          color: AppTheme.success),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Submit button
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRequest,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('إرسال الطلب'),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_empty, color: AppTheme.warning),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'لديك طلب قيد الانتظار. يجب انتظار مراجعته قبل إرسال طلب جديد.',
                              style: TextStyle(color: AppTheme.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildRoleOption({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primary.withOpacity(0.1)
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : AppTheme.textLight.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestCard(RoleRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'approved':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = AppTheme.warning;
        statusIcon = Icons.hourglass_empty;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(
                request.roleDisplayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  request.statusDisplayName,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (request.reason != null && request.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.reason!,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          if (request.rejectionReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سبب الرفض: ${request.rejectionReason}',
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 14, color: AppTheme.textLight),
              const SizedBox(width: 4),
              Text(
                _formatDate(request.createdAt),
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                ),
              ),
              if (request.status == 'pending') ...[
                const Spacer(),
                TextButton(
                  onPressed: () => _cancelRequest(request.id),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('إلغاء الطلب'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
