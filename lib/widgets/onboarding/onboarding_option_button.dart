import 'package:flutter/material.dart';
import 'package:medito/constants/styles/widget_styles.dart';

/// A full-width selectable option tile used in onboarding question screens.
///
/// Animates its border and background when [selected] is true.
class OnboardingOptionButton extends StatelessWidget {
  const OnboardingOptionButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: padding20,
          vertical: 18,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary.withAlpha(25)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outline.withAlpha(80),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
