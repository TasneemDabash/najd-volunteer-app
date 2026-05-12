import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/app_location.dart';
import '../../models/user_role.dart';
import '../../models/volunteer.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/volunteer_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/location_picker.dart';
import 'volunteer_profile_screen.dart';

enum SortOption { newest, alphabetical, city, distance }

class VolunteerListScreen extends StatefulWidget {
  const VolunteerListScreen({super.key});

  @override
  State<VolunteerListScreen> createState() => _VolunteerListScreenState();
}

class _VolunteerListScreenState extends State<VolunteerListScreen> {
  final VolunteerService _service = VolunteerService();
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();
  List<Volunteer> _volunteers = [];
  List<Volunteer> _allVolunteers = [];
  List<String> _cities = [];
  bool _loading = true;
  bool _coordinatorDirectory = false;
  String? _filterCity;
  String? _filterLocationId;
  AppLocation? _filterLocation;
  String? _filterRole;
  bool _onlineOnly = false;
  bool _availableOnly = false;
  AppLocation? _accidentLocation;
  SortOption _sort = SortOption.newest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final role = context.read<AuthProvider>().role;
      _coordinatorDirectory =
          role == UserRole.admin || role == UserRole.support;
      final all = await _service.getVolunteers(
        coordinatorDirectory: _coordinatorDirectory,
        originLat: _accidentLocation?.latitude,
        originLon: _accidentLocation?.longitude,
      );
      if (_coordinatorDirectory) {
        _cities = all
            .map((v) => v.city)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      } else {
        _cities = await _service.getDistinctCities();
      }
      _allVolunteers = all;
      _applyFiltersAndSort(_allVolunteers);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  void _applyFiltersAndSort(List<Volunteer> list) {
    var listCopy = List<Volunteer>.from(list);
    final search = _searchController.text.trim().toLowerCase();
    if (search.isNotEmpty) {
      listCopy = listCopy.where((v) {
        return v.fullName.toLowerCase().contains(search) ||
            v.city.toLowerCase().contains(search) ||
            v.phone.contains(search) ||
            v.email.toLowerCase().contains(search) ||
            (v.currentLocationName?.toLowerCase().contains(search) ?? false);
      }).toList();
    }
    if (_filterCity != null && _filterCity!.isNotEmpty) {
      listCopy = listCopy.where((v) => v.city == _filterCity).toList();
    }
    if (_filterLocationId != null && _filterLocationId!.isNotEmpty) {
      listCopy =
          listCopy.where((v) => v.currentLocationId == _filterLocationId).toList();
    }
    if (_filterRole != null && _filterRole!.isNotEmpty) {
      listCopy = listCopy
          .where((v) => (v.appRole ?? 'volunteer').toLowerCase() == _filterRole)
          .toList();
    }
    if (_onlineOnly) {
      listCopy = listCopy.where((v) => v.isOnline).toList();
    }
    if (_availableOnly) {
      listCopy = listCopy.where((v) => v.isAvailable).toList();
    }
    switch (_sort) {
      case SortOption.newest:
        listCopy.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.alphabetical:
        listCopy.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case SortOption.city:
        listCopy.sort((a, b) => a.city.compareTo(b.city));
        break;
      case SortOption.distance:
        listCopy.sort((a, b) {
          final ad = a.distanceKm;
          final bd = b.distanceKm;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
        break;
    }
    _volunteers = listCopy;
  }

  void _applyFilters() {
    _applyFiltersAndSort(_allVolunteers);
    setState(() {});
  }

  Future<void> _pickAccident() async {
    final list = await _locationService.list();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccidentPickerSheet(
        locations: list,
        currentId: _accidentLocation?.id,
        onSelected: (loc) async {
          setState(() {
            _accidentLocation = loc;
            _sort = SortOption.distance;
          });
          await _load();
        },
        onClear: () async {
          setState(() {
            _accidentLocation = null;
            if (_sort == SortOption.distance) _sort = SortOption.newest;
          });
          await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = <String>[];
    if (_filterCity != null) activeFilters.add(_filterCity!);
    if (_filterLocation != null) activeFilters.add(_filterLocation!.name);
    if (_filterRole != null) activeFilters.add('Role: $_filterRole');
    if (_onlineOnly) activeFilters.add('Online');
    if (_availableOnly) activeFilters.add('Available');
    if (_accidentLocation != null) {
      activeFilters.add('Near ${_accidentLocation!.name}');
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_coordinatorDirectory ? 'Members' : 'Volunteers'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_coordinatorDirectory)
            IconButton(
              tooltip: 'Find closest to accident',
              icon: Icon(
                _accidentLocation == null
                    ? Icons.local_hospital_outlined
                    : Icons.local_hospital_rounded,
                color: _accidentLocation == null
                    ? AppTheme.textLight
                    : AppTheme.error,
              ),
              onPressed: _pickAccident,
            ),
        ],
      ),
      body: Column(
        children: [
          SlideInAnimation(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _applyFilters(),
                  decoration: InputDecoration(
                    hintText: 'Search by name, location, phone, email...',
                    hintStyle: const TextStyle(color: AppTheme.textLight),
                    prefixIcon:
                        const Icon(Icons.search, color: AppTheme.primary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: AppTheme.textLight),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppTheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SlideInAnimation(
            delay: const Duration(milliseconds: 50),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Pill(
                    icon: Icons.bolt_rounded,
                    label: 'Online',
                    selected: _onlineOnly,
                    color: AppTheme.success,
                    onTap: () {
                      setState(() => _onlineOnly = !_onlineOnly);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.event_available_rounded,
                    label: 'Available',
                    selected: _availableOnly,
                    color: AppTheme.primary,
                    onTap: () {
                      setState(() => _availableOnly = !_availableOnly);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  if (_coordinatorDirectory) ...[
                    _ModernDropdown(
                      icon: Icons.shield_outlined,
                      label: _filterRole == null
                          ? 'All Roles'
                          : 'Role: $_filterRole',
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All Roles')),
                        DropdownMenuItem(
                            value: 'volunteer', child: Text('Volunteer')),
                        DropdownMenuItem(
                            value: 'support', child: Text('Support')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (v) {
                        setState(() => _filterRole = v);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  _ModernDropdown(
                    icon: Icons.location_city,
                    label: _filterCity ?? 'All Cities',
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Cities'),
                      ),
                      ..._cities.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _filterCity = v);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 8),
                  _ModernSortChip(
                    currentSort: _sort,
                    hasOrigin: _accidentLocation != null,
                    onSortChanged: (v) {
                      setState(() => _sort = v);
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_coordinatorDirectory)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                ),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: LocationPicker(
                  selectedId: _filterLocationId,
                  label: 'Filter by current location',
                  hint: 'Any location',
                  includeNoneOption: true,
                  noneLabel: 'Any location',
                  onChanged: (loc) {
                    setState(() {
                      _filterLocation = loc;
                      _filterLocationId = loc?.id;
                    });
                    _applyFilters();
                  },
                ),
              ),
            ),
          if (activeFilters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: activeFilters
                    .map(
                      (f) => Chip(
                        label: Text(f, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: AppTheme.primary.withOpacity(0.08),
                        labelStyle: const TextStyle(color: AppTheme.primary),
                      ),
                    )
                    .toList(),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _volunteers.isEmpty
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
                                Icons.people_outline,
                                size: 48,
                                color: AppTheme.secondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              child: Text(
                                'No volunteers match your filters.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _volunteers.length,
                          itemBuilder: (context, index) {
                            final v = _volunteers[index];
                            return SlideInAnimation(
                              delay: Duration(milliseconds: index * 40),
                              child: _ModernVolunteerCard(
                                volunteer: v,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VolunteerProfileScreen(
                                        volunteerId: v.id),
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: selected ? color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<DropdownMenuItem<String?>> items;
  final void Function(String?) onChanged;

  const _ModernDropdown({
    required this.icon,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: null,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 20, color: AppTheme.textLight),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ModernSortChip extends StatelessWidget {
  final SortOption currentSort;
  final bool hasOrigin;
  final void Function(SortOption) onSortChanged;

  const _ModernSortChip({
    required this.currentSort,
    required this.hasOrigin,
    required this.onSortChanged,
  });

  String get _sortLabel {
    switch (currentSort) {
      case SortOption.newest:
        return 'Newest';
      case SortOption.alphabetical:
        return 'A–Z';
      case SortOption.city:
        return 'City';
      case SortOption.distance:
        return 'Closest';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortOption>(
      initialValue: currentSort,
      onSelected: onSortChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 45),
      itemBuilder: (context) => [
        _buildMenuItem(SortOption.newest, 'Newest', Icons.access_time),
        _buildMenuItem(
            SortOption.alphabetical, 'Alphabetical', Icons.sort_by_alpha),
        _buildMenuItem(SortOption.city, 'By City', Icons.location_city),
        if (hasOrigin)
          _buildMenuItem(SortOption.distance, 'Closest to accident',
              Icons.near_me_rounded),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _sortLabel,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<SortOption> _buildMenuItem(
      SortOption option, String label, IconData icon) {
    return PopupMenuItem(
      value: option,
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: currentSort == option
                  ? AppTheme.primary
                  : AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight:
                  currentSort == option ? FontWeight.w600 : FontWeight.normal,
              color: currentSort == option
                  ? AppTheme.primary
                  : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccidentPickerSheet extends StatelessWidget {
  const _AccidentPickerSheet({
    required this.locations,
    required this.currentId,
    required this.onSelected,
    required this.onClear,
  });

  final List<AppLocation> locations;
  final String? currentId;
  final ValueChanged<AppLocation> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textLight.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.local_hospital_rounded,
                      color: AppTheme.error),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Accident / incident location',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (currentId != null)
                    TextButton(
                      onPressed: () {
                        onClear();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear'),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick where the accident is. We will compute the closest volunteers using coordinates.',
                style:
                    TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: locations.length,
                  itemBuilder: (context, i) {
                    final l = locations[i];
                    final selected = l.id == currentId;
                    return ListTile(
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.place_outlined,
                        color:
                            selected ? AppTheme.primary : AppTheme.textLight,
                      ),
                      title: Text(l.name),
                      subtitle: Text(l.region),
                      onTap: () {
                        onSelected(l);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModernVolunteerCard extends StatefulWidget {
  final Volunteer volunteer;
  final VoidCallback onTap;

  const _ModernVolunteerCard({
    required this.volunteer,
    required this.onTap,
  });

  @override
  State<_ModernVolunteerCard> createState() => _ModernVolunteerCardState();
}

class _ModernVolunteerCardState extends State<_ModernVolunteerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.volunteer;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AppTheme.secondary,
                            child: Text(
                              v.fullName.isNotEmpty
                                  ? v.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (v.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 4,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
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
                                v.fullName.isNotEmpty ? v.fullName : v.email,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (v.appRole != null && v.appRole!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppTheme.primary.withOpacity(0.25),
                                  ),
                                ),
                                child: Text(
                                  v.appRole!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 14, color: AppTheme.textLight),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                v.currentLocationName ??
                                    (v.city.isEmpty ? 'No location' : v.city),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (v.distanceKm != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${v.distanceKm!.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (v.isAvailable)
                              _MicroBadge(
                                label: 'Available',
                                color: AppTheme.success,
                              )
                            else
                              _MicroBadge(
                                label: 'Busy',
                                color: AppTheme.warning,
                              ),
                            ...v.skills.take(2).map(
                                  (s) => _MicroBadge(
                                    label: s,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.textLight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
