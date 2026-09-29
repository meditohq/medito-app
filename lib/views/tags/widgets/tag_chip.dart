import 'package:flutter/material.dart';
import 'package:medito/utils/utils.dart';

/// Small rounded pill naming a tag. Tapping opens the tag's track list.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Material(
      color: theme.cardColor,
      shape: StadiumBorder(
        side: BorderSide(color: theme.colorScheme.outline.withOpacityValue(0.3)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
