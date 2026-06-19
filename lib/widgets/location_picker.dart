import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/app_location.dart';
import '../services/location_service.dart';

/// A dropdown/search picker for `public.locations`. Replaces free-text city
/// fields and feeds clean coordinates downstream (e.g. for nearest-volunteer
/// distance calculations).
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.label = 'Location',
    this.hint = 'Choose a location',
    this.includeNoneOption = false,
    this.noneLabel = 'No specific location',
  });

  final String? selectedId;
  final ValueChanged<AppLocation?> onChanged;
  final String label;
  final String hint;
  final bool includeNoneOption;
  final String noneLabel;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final LocationService _service = LocationService();
  List<AppLocation> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.list();
      if (!mounted) return;
      setState(() {
        _locations = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  AppLocation? get _selected {
    if (widget.selectedId == null) return null;
    try {
      return _locations.firstWhere((l) => l.id == widget.selectedId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openPicker() async {
    if (_loading) return;
    if (_locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error ??
              'لا توجد مواقع. نفّذ supabase/migrate_locations_calls_voice.sql في Supabase.'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_LocationPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        locations: _locations,
        currentId: widget.selectedId,
        includeNone: widget.includeNoneOption,
        noneLabel: widget.noneLabel,
      ),
    );

    if (!mounted || result == null) return;
    if (result.clearSelection) {
      widget.onChanged(null);
    } else if (result.selection != null) {
      widget.onChanged(result.selection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openPicker,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected != null
                  ? AppTheme.primary.withOpacity(0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.place_rounded,
                color: selected != null ? AppTheme.primary : AppTheme.textLight,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loading
                          ? 'جاري التحميل…'
                          : (selected?.displayName ?? widget.hint),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: selected != null
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                    if (selected != null &&
                        selected.latitude != null &&
                        selected.longitude != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '(${selected.latitude!.toStringAsFixed(3)}, ${selected.longitude!.toStringAsFixed(3)})',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationPickerResult {
  const _LocationPickerResult({this.selection, this.clearSelection = false});
  final AppLocation? selection;
  final bool clearSelection;
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.locations,
    required this.currentId,
    required this.includeNone,
    required this.noneLabel,
  });

  final List<AppLocation> locations;
  final String? currentId;
  final bool includeNone;
  final String noneLabel;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppLocation> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return widget.locations;
    return widget.locations.where((l) {
      return l.name.toLowerCase().contains(q) ||
          l.region.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                  const Icon(Icons.place_rounded, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'اختر الموقع',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppTheme.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'ابحث بالاسم أو المنطقة',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (widget.includeNone)
                      ListTile(
                        leading: const Icon(Icons.do_not_disturb_alt_outlined),
                        title: Text(widget.noneLabel),
                        onTap: () => Navigator.pop(
                          context,
                          const _LocationPickerResult(clearSelection: true),
                        ),
                      ),
                    ..._filtered.map((l) {
                      final selected = l.id == widget.currentId;
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.place_outlined,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textLight,
                        ),
                        title: Text(l.name,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                        subtitle: Text(l.region),
                        onTap: () => Navigator.pop(
                          context,
                          _LocationPickerResult(selection: l),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
