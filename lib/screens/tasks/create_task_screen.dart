import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../l10n/app_strings.dart';
import '../../models/app_location.dart';
import '../../models/task_template.dart';
import '../../models/user_role.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_publish_request_service.dart';
import '../../services/task_service.dart';
import '../../services/task_template_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/location_picker.dart';

/// Create a task (coordinator) or submit a publish request (volunteer).
class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key, this.publishOnly = false});

  /// When true, submits for admin/support approval instead of creating directly.
  final bool publishOnly;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();
  final VolunteerService _volunteerService = VolunteerService();
  final TaskTemplateService _templateService = TaskTemplateService();
  final TaskPublishRequestService _publishService = TaskPublishRequestService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _volunteerSearchController = TextEditingController();

  AppLocation? _location;
  DateTime _date = DateTime.now();
  final List<String> _requiredSkills = [];
  final List<String> _selectedVolunteerIds = [];
  List<Volunteer> _allVolunteers = [];
  List<TaskTemplate> _templates = [];
  String? _selectedTemplateId;

  bool _loading = false;
  bool _volunteersLoading = true;
  String? _volunteerLoadError;

  bool _filterOnlineOnly = false;
  bool _filterAvailableOnly = false;
  bool _filterMatchSkills = true;

  bool get _isPublishOnly => widget.publishOnly;

  List<Volunteer> get _filteredVolunteers {
    var list = List<Volunteer>.from(_allVolunteers);
    final q = _volunteerSearchController.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((v) {
        return v.fullName.toLowerCase().contains(q) ||
            v.city.toLowerCase().contains(q) ||
            v.email.toLowerCase().contains(q) ||
            (v.currentLocationName?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    if (_filterOnlineOnly) {
      list = list.where((v) => v.isOnline).toList();
    }
    if (_filterAvailableOnly) {
      list = list.where((v) => v.isAvailable).toList();
    }
    if (_filterMatchSkills && _requiredSkills.isNotEmpty) {
      list = list
          .where((v) => v.skills.any((s) => _requiredSkills.contains(s)))
          .toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _volunteerSearchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTemplates();
      if (!_isPublishOnly) _loadVolunteers();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _volunteerSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    final list = await _templateService.getActiveTemplates();
    if (mounted) setState(() => _templates = list);
  }

  Future<void> _loadVolunteers() async {
    if (!mounted || _isPublishOnly) return;
    setState(() {
      _volunteersLoading = true;
      _volunteerLoadError = null;
    });
    try {
      final role = context.read<AuthProvider>().role;
      final coordinator = role == UserRole.admin || role == UserRole.support;
      final list = await _volunteerService.getVolunteers(
        coordinatorDirectory: coordinator,
        originLat: _location?.latitude,
        originLon: _location?.longitude,
        skills: _filterMatchSkills && _requiredSkills.isNotEmpty
            ? _requiredSkills
            : null,
        onlineOnly: _filterOnlineOnly ? true : null,
        availableOnly: _filterAvailableOnly ? true : null,
      );
      final assignable = coordinator
          ? list.where((v) {
              final r = v.appRole?.toLowerCase();
              return r == null || r == 'volunteer';
            }).toList()
          : list;
      if (mounted) {
        setState(() {
          _allVolunteers = assignable;
          _volunteersLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _volunteersLoading = false;
          _volunteerLoadError = e.toString();
        });
      }
    }
  }

  void _applyTemplate(TaskTemplate t) {
    setState(() {
      _selectedTemplateId = t.id;
      _titleController.text = t.title;
      _descriptionController.text = t.description;
      _requiredSkills
        ..clear()
        ..addAll(t.requiredSkills);
    });
    if (!_isPublishOnly) _loadVolunteers();
    _templateService.recordUsage(t.id);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      _snack(AppStrings.pickLocationError, isError: true);
      return;
    }
    if (_requiredSkills.isEmpty) {
      _snack(AppStrings.pickSkillError, isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      if (_isPublishOnly) {
        await _publishService.createRequest(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _location!.name,
          locationId: _location!.id,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          requiredSkills: _requiredSkills,
          scheduledDate: _date,
        );
        if (mounted) {
          _snack(AppStrings.requestSubmitted);
          Navigator.pop(context);
        }
      } else {
        final task = await _taskService.createTask(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _location!.name,
          locationId: _location!.id,
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          requiredSkills: _requiredSkills,
          date: _date,
        );
        if (_selectedVolunteerIds.isNotEmpty) {
          await _taskService.assignVolunteers(task.id, _selectedVolunteerIds);
        }
        if (mounted) {
          _snack(AppStrings.taskCreated, success: true);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        _snack(
          '$e\n\nإذا ذُكر «date» أو «location»، نفّذ supabase/task_templates_and_publish_requests.sql في Supabase.',
          isError: true,
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _snack(String msg, {bool isError = false, bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 13)),
        backgroundColor: isError
            ? AppTheme.error
            : success
                ? AppTheme.success
                : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 6 : 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permanent =
        _templates.where((t) => t.isPermanent).toList();
    final suggested = _templates
        .where((t) => !t.isPermanent)
        .toList()
      ..sort((a, b) => b.usageCount.compareTo(a.usageCount));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isPublishOnly
            ? AppStrings.requestPublishTask
            : AppStrings.createTask),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SlideInAnimation(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.secondaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondary.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isPublishOnly
                              ? Icons.send_rounded
                              : Icons.add_task_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _isPublishOnly
                              ? 'اقترح مهمة جديدة. سيراجعها فريق الدعم أو الإدارة قبل النشر.'
                              : AppStrings.createTaskHero,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_templates.isNotEmpty) ...[
                const SizedBox(height: 20),
                _TemplateSection(
                  title: AppStrings.permanentTasks,
                  templates: permanent,
                  selectedId: _selectedTemplateId,
                  onSelect: _applyTemplate,
                ),
                if (suggested.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _TemplateSection(
                    title: AppStrings.suggestedTasks,
                    templates: suggested,
                    selectedId: _selectedTemplateId,
                    onSelect: _applyTemplate,
                    showUsage: true,
                  ),
                ],
              ],
              const SizedBox(height: 22),
              SlideInAnimation(
                delay: const Duration(milliseconds: 80),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: AppStrings.taskTitle,
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? AppStrings.required_
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: AppStrings.description,
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LocationPicker(
                        selectedId: _location?.id,
                        label: AppStrings.location,
                        hint: AppStrings.pickLocation,
                        onChanged: (loc) {
                          setState(() => _location = loc);
                          if (!_isPublishOnly && loc?.latitude != null) {
                            _loadVolunteers();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      Material(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_rounded,
                                    color: AppTheme.primary),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      AppStrings.scheduledDate,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.yMMMMd('ar')
                                          .add_jm()
                                          .format(_date),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_left,
                                    color: AppTheme.textLight),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideInAnimation(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  AppStrings.requiredSkills,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                ),
              ),
              const SizedBox(height: 10),
              SlideInAnimation(
                delay: const Duration(milliseconds: 140),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skillOptions.map((s) {
                    final selected = _requiredSkills.contains(s);
                    return FilterChip(
                      label: Text(
                        s,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      selected: selected,
                      selectedColor: AppTheme.primary.withOpacity(0.18),
                      checkmarkColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      side: BorderSide(
                        color: selected
                            ? AppTheme.primary
                            : const Color(0xFFE2E8F0),
                      ),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _requiredSkills.add(s);
                          } else {
                            _requiredSkills.remove(s);
                          }
                        });
                        if (!_isPublishOnly) _loadVolunteers();
                      },
                    );
                  }).toList(),
                ),
              ),
              if (!_isPublishOnly) ...[
                const SizedBox(height: 24),
                _VolunteerAssignmentSection(
                  volunteersLoading: _volunteersLoading,
                  volunteerLoadError: _volunteerLoadError,
                  hasLocationCoords: _location?.latitude != null,
                  searchController: _volunteerSearchController,
                  filterOnlineOnly: _filterOnlineOnly,
                  filterAvailableOnly: _filterAvailableOnly,
                  filterMatchSkills: _filterMatchSkills,
                  onFilterChanged: (online, available, matchSkills) {
                    setState(() {
                      _filterOnlineOnly = online;
                      _filterAvailableOnly = available;
                      _filterMatchSkills = matchSkills;
                    });
                    _loadVolunteers();
                  },
                  onRefresh: _loadVolunteers,
                  volunteers: _filteredVolunteers,
                  selectedIds: _selectedVolunteerIds,
                  onToggle: (id, selected) {
                    setState(() {
                      if (selected) {
                        _selectedVolunteerIds.remove(id);
                      } else {
                        _selectedVolunteerIds.add(id);
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 28),
              SlideInAnimation(
                delay: const Duration(milliseconds: 200),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppTheme.buttonShadow,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _loading ? null : _submit,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isPublishOnly
                                      ? AppStrings.submitForReview
                                      : AppStrings.createTask,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateSection extends StatelessWidget {
  const _TemplateSection({
    required this.title,
    required this.templates,
    required this.selectedId,
    required this.onSelect,
    this.showUsage = false,
  });

  final String title;
  final List<TaskTemplate> templates;
  final String? selectedId;
  final void Function(TaskTemplate) onSelect;
  final bool showUsage;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = templates[i];
              final selected = selectedId == t.id;
              return ActionChip(
                label: Text(
                  showUsage && t.usageCount > 0
                      ? '${t.title} (${t.usageCount})'
                      : t.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppTheme.primary,
                  ),
                ),
                backgroundColor:
                    selected ? AppTheme.primary : AppTheme.surface,
                side: BorderSide(
                  color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
                ),
                onPressed: () => onSelect(t),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VolunteerAssignmentSection extends StatelessWidget {
  const _VolunteerAssignmentSection({
    required this.volunteersLoading,
    required this.volunteerLoadError,
    required this.hasLocationCoords,
    required this.searchController,
    required this.filterOnlineOnly,
    required this.filterAvailableOnly,
    required this.filterMatchSkills,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.volunteers,
    required this.selectedIds,
    required this.onToggle,
  });

  final bool volunteersLoading;
  final String? volunteerLoadError;
  final bool hasLocationCoords;
  final TextEditingController searchController;
  final bool filterOnlineOnly;
  final bool filterAvailableOnly;
  final bool filterMatchSkills;
  final void Function(bool online, bool available, bool matchSkills)
      onFilterChanged;
  final VoidCallback onRefresh;
  final List<Volunteer> volunteers;
  final List<String> selectedIds;
  final void Function(String id, bool wasSelected) onToggle;

  @override
  Widget build(BuildContext context) {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                AppStrings.assignVolunteers,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
              ),
              const SizedBox(width: 8),
              if (hasLocationCoords)
                const Chip(
                  label: Text(AppStrings.closestFirst,
                      style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFFE0F2FE),
                  labelStyle: TextStyle(color: AppTheme.primary),
                ),
              const Spacer(),
              if (volunteersLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: AppStrings.refresh,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: AppStrings.searchVolunteers,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              fillColor: AppTheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text(AppStrings.onlineOnly,
                    style: TextStyle(fontSize: 12)),
                selected: filterOnlineOnly,
                onSelected: (v) =>
                    onFilterChanged(v, filterAvailableOnly, filterMatchSkills),
              ),
              FilterChip(
                label: const Text(AppStrings.availableOnly,
                    style: TextStyle(fontSize: 12)),
                selected: filterAvailableOnly,
                onSelected: (v) =>
                    onFilterChanged(filterOnlineOnly, v, filterMatchSkills),
              ),
              FilterChip(
                label: const Text(AppStrings.matchSkills,
                    style: TextStyle(fontSize: 12)),
                selected: filterMatchSkills,
                onSelected: (v) =>
                    onFilterChanged(filterOnlineOnly, filterAvailableOnly, v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (volunteerLoadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                volunteerLoadError!,
                style: const TextStyle(fontSize: 12, color: AppTheme.error),
              ),
            ),
          if (volunteersLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (volunteers.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                AppStrings.noVolunteersToAssign,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.35,
                ),
              ),
            )
          else
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: volunteers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final v = volunteers[i];
                  final selected = selectedIds.contains(v.id);
                  return Material(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => onToggle(v.id, selected),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppTheme.primary
                                : const Color(0xFFE2E8F0),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textLight,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.fullName.isNotEmpty
                                              ? v.fullName
                                              : v.email,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (v.isOnline)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.success
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            AppStrings.online,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.success,
                                            ),
                                          ),
                                        ),
                                      if (v.distanceKm != null) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '${v.distanceKm!.toStringAsFixed(1)} ${AppStrings.km}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${v.currentLocationName ?? v.city} • ${v.skills.take(3).join('، ')}${v.skills.length > 3 ? '…' : ''}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'تم اختيار ${selectedIds.length} متطوع',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
