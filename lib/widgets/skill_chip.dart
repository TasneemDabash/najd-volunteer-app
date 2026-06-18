import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Skill tag with readable contrast (section label + chips).
class SkillSection extends StatelessWidget {
  const SkillSection({
    super.key,
    required this.skills,
    this.label,
    this.compact = false,
  });

  final List<String> skills;
  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (skills.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: skills.map((s) => SkillChip(label: s, compact: compact)).toList(),
        ),
      ],
    );
  }
}

class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.label,
    this.compact = false,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool compact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        gradient: selected ? null : AppTheme.secondaryGradient,
        color: selected ? AppTheme.primary.withOpacity(0.14) : null,
        borderRadius: BorderRadius.circular(12),
        border: selected
            ? Border.all(color: AppTheme.primary, width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: selected ? AppTheme.primary : Colors.white,
        ),
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(onTap: onTap, child: child);
  }
}
