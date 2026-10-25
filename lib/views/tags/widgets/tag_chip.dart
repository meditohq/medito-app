import 'package:flutter/material.dart';
import 'package:medito/utils/utils.dart';

/// Small rounded pill naming a tag. Tapping opens the tag's track list.
///
/// The pill stays compact, but the touch target around it is at least 48px
/// tall (the platform minimum).
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final pill = Material(
      color: theme.cardColor,
      shape: StadiumBorder(
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacityValue(0.3),
        ),
      ),
      child: Semantics(
        button: true,
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
      ),
    );
    // Taps in the slack above and below the pill count too; the pill's
    // InkWell carries the semantics.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minTapHeight),
        child: Center(widthFactor: 1, child: pill),
      ),
    );
  }

  static const minTapHeight = 48.0;
}
