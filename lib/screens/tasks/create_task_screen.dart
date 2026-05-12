import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/app_location.dart';
import '../../models/user_role.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/task_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/location_picker.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();
  final VolunteerService _volunteerService = VolunteerService();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  AppLocation? _location;
  DateTime _date = DateTime.now();
  final List<String> _requiredSkills = [];
  final List<String> _selectedVolunteerIds = [];
  List<Volunteer> _volunteers = [];
  bool _loading = false;
  bool _volunteersLoading = true;
  String? _volunteerLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVolunteers());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadVolunteers() async {
    if (!mounted) return;
    setState(() {
      _volunteersLoading = true;
      _volunteerLoadError = null;
    });
    try {
      final role = context.read<AuthProvider>().role;
      final coordinator =
          role == UserRole.admin || role == UserRole.support;
      final list = await _volunteerService.getVolunteers(
        coordinatorDirectory: coordinator,
        originLat: _location?.latitude,
        originLon: _location?.longitude,
      );
      final assignable = coordinator
          ? list
              .where((v) {
                final r = v.appRole?.toLowerCase();
                return r == null || r == 'volunteer';
              })
              .toList()
          : list;
      if (mounted) {
        setState(() {
          _volunteers = assignable;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pick a location from the list'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    if (_requiredSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pick at least one required skill'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Task created'),
              ],
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e\n\nIf this mentions "date" or "location", run supabase/support_messages_and_tasks.sql in Supabase.',
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Create task'),
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
                        child: const Icon(
                          Icons.add_task_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Plan work, attach skills, and optionally assign volunteers.',
                          style: TextStyle(
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
                          labelText: 'Task title',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LocationPicker(
                        selectedId: _location?.id,
                        label: 'Location',
                        hint: 'Pick a location',
                        onChanged: (loc) {
                          setState(() => _location = loc);
                          if (loc?.latitude != null) {
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
                                    Text(
                                      'Scheduled date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.textLight,
                                      ),
                                    ),
                                    Text(
                                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                const Icon(Icons.chevron_right,
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
                  'Required skills',
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
                      label: Text(s),
                      selected: selected,
                      selectedColor: AppTheme.primary.withOpacity(0.15),
                      checkmarkColor: AppTheme.primary,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _requiredSkills.add(s);
                          } else {
                            _requiredSkills.remove(s);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),
              SlideInAnimation(
                delay: const Duration(milliseconds: 160),
                child: Row(
                  children: [
                    Text(
                      'Assign volunteers',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (_location?.latitude != null)
                      const Chip(
                        label: Text('Closest first',
                            style: TextStyle(fontSize: 11)),
                        backgroundColor: Color(0xFFE0F2FE),
                        labelStyle: TextStyle(color: AppTheme.primary),
                      ),
                    const Spacer(),
                    if (_volunteersLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        onPressed: _loadVolunteers,
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Refresh list',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (_volunteerLoadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _volunteerLoadError!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              if (_volunteersLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_volunteers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_outline,
                          color: AppTheme.textLight, size: 36),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'No volunteer profiles to assign yet. '
                          'Users need role “volunteer” and a profiles row (sign in once).',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._volunteers.map((v) {
                  final selected = _selectedVolunteerIds.contains(v.id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedVolunteerIds.remove(v.id);
                            } else {
                              _selectedVolunteerIds.add(v.id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
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
                                            v.fullName.isNotEmpty
                                                ? v.fullName
                                                : v.email,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (v.isOnline)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            margin:
                                                const EdgeInsets.only(left: 6),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.success,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        if (v.distanceKm != null) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '${v.distanceKm!.toStringAsFixed(1)} km',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      '${v.currentLocationName ?? v.city} • ${v.skills.take(3).join(', ')}${v.skills.length > 3 ? '…' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
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
                    ),
                  );
                }),
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
                              : const Text(
                                  'Create task',
                                  style: TextStyle(
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
