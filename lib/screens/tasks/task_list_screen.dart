import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/task_model.dart';
import '../../models/user_role.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_service.dart';
import '../../widgets/animations.dart';
import 'create_task_screen.dart';
import 'task_details_screen.dart';
import 'task_publish_requests_screen.dart';
import 'task_templates_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key, this.initialStatus});

  final TaskStatus? initialStatus;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskService _service = TaskService();
  List<TaskModel> _allTasks = []; // All tasks for counting
  List<TaskModel> _tasks = [];
  List<TaskModel> _filteredTasks = [];
  TaskStatus? _filterStatus;
  bool _loading = true;

  // Advanced filters
  Set<String> _selectedSkills = {};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;

  // Task counts
  int get _pendingCount => _allTasks.where((t) => t.status == TaskStatus.pending).length;
  int get _activeCount => _allTasks.where((t) => t.status == TaskStatus.active).length;
  int get _completedCount => _allTasks.where((t) => t.status == TaskStatus.completed).length;

  @override
  void initState() {
    super.initState();
    _filterStatus = widget.initialStatus;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load all tasks for counting
      final allList = await _service.getTasks();
      final list = _filterStatus != null
          ? allList.where((t) => t.status == _filterStatus).toList()
          : allList;
      if (mounted) {
        _allTasks = allList;
        setState(() {
          _tasks = list;
          _applyFilters();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorPrefix} $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    _filteredTasks = _tasks.where((task) {
      // Filter by skills
      if (_selectedSkills.isNotEmpty) {
        final hasMatchingSkill = task.requiredSkills.any(
          (skill) => _selectedSkills.contains(skill),
        );
        if (!hasMatchingSkill) return false;
      }

      // Filter by date range
      if (_startDate != null) {
        if (task.date.isBefore(_startDate!)) return false;
      }
      if (_endDate != null) {
        final endOfDay = DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
        );
        if (task.date.isAfter(endOfDay)) return false;
      }

      return true;
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      _selectedSkills.clear();
      _startDate = null;
      _endDate = null;
      _applyFilters();
    });
  }

  bool get _hasActiveFilters =>
      _selectedSkills.isNotEmpty || _startDate != null || _endDate != null;

  Future<void> _exportToExcel({bool exportAll = true}) async {
    final tasksToExport = exportAll ? _tasks : _filteredTasks;

    if (tasksToExport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('لا توجد مهام للتصدير'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    try {
      final excel = Excel.createExcel();
      final sheet = excel['المهام'];

      // Header row
      sheet.appendRow([
        TextCellValue('العنوان'),
        TextCellValue('الوصف'),
        TextCellValue('الموقع'),
        TextCellValue('التاريخ'),
        TextCellValue('الوقت'),
        TextCellValue('الحالة'),
        TextCellValue('المهارات المطلوبة'),
        TextCellValue('تاريخ الإنشاء'),
      ]);

      // Data rows
      for (final task in tasksToExport) {
        sheet.appendRow([
          TextCellValue(task.title),
          TextCellValue(task.description),
          TextCellValue(task.displayLocation),
          TextCellValue(DateFormat('yyyy-MM-dd').format(task.date)),
          TextCellValue(DateFormat('HH:mm').format(task.date)),
          TextCellValue(task.status.displayName),
          TextCellValue(task.requiredSkills.join(', ')),
          TextCellValue(DateFormat('yyyy-MM-dd').format(task.createdAt)),
        ]);
      }

      // Remove default sheet
      excel.delete('Sheet1');

      final bytes = excel.save();
      if (bytes == null) throw Exception('فشل إنشاء الملف');

      final fileName = 'tasks_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';

      if (kIsWeb) {
        // For web, use share_plus which handles web downloads
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تصدير الويب غير مدعوم حالياً'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        // For mobile/desktop
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'تصدير المهام - نجد للتطوع',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تصدير ${tasksToExport.length} مهمة'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في التصدير: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.textLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'تصدير المهام إلى Excel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.select_all, color: AppTheme.primary),
              ),
              title: const Text('تصدير جميع المهام'),
              subtitle: Text('${_tasks.length} مهمة'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel(exportAll: true);
              },
            ),
            if (_hasActiveFilters) ...[
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.filter_list, color: AppTheme.secondary),
                ),
                title: const Text('تصدير المهام المفلترة'),
                subtitle: Text('${_filteredTasks.length} مهمة'),
                onTap: () {
                  Navigator.pop(context);
                  _exportToExcel(exportAll: false);
                },
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: AppTheme.surface,
              onSurface: AppTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _applyFilters();
      });
    }
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppTheme.success;
      case TaskStatus.active:
        return AppTheme.warning;
      default:
        return AppTheme.textLight;
    }
  }

  LinearGradient _getStatusGradient(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return AppTheme.successGradient;
      case TaskStatus.active:
        return AppTheme.warningGradient;
      default:
        return const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFFCBD5E1)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final isCoordinator =
        role == UserRole.admin || role == UserRole.support;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(AppStrings.tasks),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Filter toggle button
          IconButton(
            onPressed: () => setState(() => _showFilters = !_showFilters),
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              backgroundColor: AppTheme.secondary,
              child: Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: _hasActiveFilters ? AppTheme.secondary : null,
              ),
            ),
            tooltip: 'تصفية متقدمة',
          ),
          // Export button
          IconButton(
            onPressed: _showExportOptions,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'تصدير Excel',
          ),
          if (isCoordinator)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                final page = v == 'templates'
                    ? const TaskTemplatesScreen()
                    : const TaskPublishRequestsScreen();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                );
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'templates',
                  child: Text(AppStrings.manageTemplates),
                ),
                PopupMenuItem(
                  value: 'requests',
                  child: Text(AppStrings.publishRequests),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
              ).then((_) => _load()),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Task summary cards
          if (!_loading)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _TaskCountCard(
                      label: 'قيد الانتظار',
                      count: _pendingCount,
                      color: AppTheme.textLight,
                      icon: Icons.pending_actions,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TaskCountCard(
                      label: 'نشطة',
                      count: _activeCount,
                      color: AppTheme.warning,
                      icon: Icons.play_circle_outline,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TaskCountCard(
                      label: 'مكتملة',
                      count: _completedCount,
                      color: AppTheme.success,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ],
              ),
            ),

          // Status filter chips
          SlideInAnimation(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  _ModernFilterChip(
                    label: AppStrings.all,
                    selected: _filterStatus == null,
                    onTap: () => setState(() {
                      _filterStatus = null;
                      _load();
                    }),
                  ),
                  ...TaskStatus.values.map((s) => _ModernFilterChip(
                        label: s.displayName,
                        selected: _filterStatus == s,
                        color: _getStatusColor(s),
                        gradient: _getStatusGradient(s),
                        onTap: () => setState(() {
                          _filterStatus = s;
                          _load();
                        }),
                      )),
                ],
              ),
            ),
          ),

          // Advanced filters panel
          if (_showFilters)
            SlideInAnimation(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تصفية متقدمة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        if (_hasActiveFilters)
                          TextButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('مسح'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.error,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Skills filter
                    const Text(
                      'المهارات',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: skillOptions.map((skill) {
                        final isSelected = _selectedSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSkills.add(skill);
                              } else {
                                _selectedSkills.remove(skill);
                              }
                              _applyFilters();
                            });
                          },
                          selectedColor: AppTheme.secondary.withOpacity(0.2),
                          checkmarkColor: AppTheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppTheme.secondary
                                : AppTheme.textSecondary,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Date range filter
                    const Text(
                      'نطاق التاريخ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _startDate != null
                                ? AppTheme.secondary
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              color: _startDate != null
                                  ? AppTheme.secondary
                                  : AppTheme.textLight,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _startDate != null && _endDate != null
                                    ? '${DateFormat('d MMM').format(_startDate!)} - ${DateFormat('d MMM').format(_endDate!)}'
                                    : 'اختر نطاق التاريخ',
                                style: TextStyle(
                                  color: _startDate != null
                                      ? AppTheme.textPrimary
                                      : AppTheme.textLight,
                                ),
                              ),
                            ),
                            if (_startDate != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _startDate = null;
                                    _endDate = null;
                                    _applyFilters();
                                  });
                                },
                                child: const Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppTheme.textLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Results count
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'تم العثور على ${_filteredTasks.length} مهمة',
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Task list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.assignment_outlined,
                                size: 48,
                                color: AppTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _hasActiveFilters
                                  ? 'لا توجد مهام تطابق الفلتر'
                                  : 'لا توجد مهام',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (_hasActiveFilters) ...[
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _clearFilters,
                                icon: const Icon(Icons.clear),
                                label: const Text('مسح الفلتر'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredTasks.length,
                          itemBuilder: (context, index) {
                            final task = _filteredTasks[index];
                            return SlideInAnimation(
                              delay: Duration(milliseconds: index * 50),
                              child: _ModernTaskCard(
                                task: task,
                                statusColor: _getStatusColor(task.status),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        TaskDetailsScreen(taskId: task.id),
                                  ),
                                ).then((_) => _load()),
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

class _ModernFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final LinearGradient? gradient;
  final VoidCallback onTap;

  const _ModernFilterChip({
    required this.label,
    required this.selected,
    this.color,
    this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? (gradient ?? AppTheme.primaryGradient) : null,
            color: selected ? null : AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: (color ?? AppTheme.primary).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : AppTheme.cardShadow,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernTaskCard extends StatefulWidget {
  final TaskModel task;
  final Color statusColor;
  final VoidCallback onTap;

  const _ModernTaskCard({
    required this.task,
    required this.statusColor,
    required this.onTap,
  });

  @override
  State<_ModernTaskCard> createState() => _ModernTaskCardState();
}

class _ModernTaskCardState extends State<_ModernTaskCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        transform: Matrix4.identity()
          ..translate(0.0, _isHovered ? -2.0 : 0.0),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isHovered ? AppTheme.cardShadowHover : AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.task.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: widget.statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: widget.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              widget.task.status.displayName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Location and date
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppTheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.task.location,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: AppTheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat.MMMd().format(widget.task.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Skills
                  if (widget.task.requiredSkills.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.task.requiredSkills.take(3).map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: AppTheme.secondaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _TaskCountCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
