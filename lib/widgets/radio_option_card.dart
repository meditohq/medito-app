import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';

/// A tappable card with a radio indicator, title and description, for picking
/// one option from a short list (settings sheets). The selected card gets a
/// brand-purple border; the rest keep a hairline so the layout never shifts.
class RadioOptionCard extends StatelessWidget {
  const RadioOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  /// Shown after the text, vertically centred: a theme icon, an app-icon
  /// preview.
  final Widget? trailing;

  static const _radius = 14.0;
  static const _borderWidth = 1.5;
  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = context.brandPurple;
    final border = selected ? accent : onSurface.withValues(alpha: 0.10);

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      label: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: AnimatedContainer(
            duration: _duration,
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(padding16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(_radius),
              border: Border.all(color: border, width: _borderWidth),
            ),
            child: ExcludeSemantics(
              child: Row(
                crossAxisAlignment: description == null
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: description == null ? 0 : 1),
                    child: RadioDot(selected: selected, accent: accent),
                  ),
                  const SizedBox(width: padding12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                          ),
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onSurface.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: padding12),
                    trailing!,
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

/// The radio indicator used by [RadioOptionCard], exposed so plain list rows
/// in sheets (e.g. background sounds) share the same control.
class RadioDot extends StatelessWidget {
  const RadioDot({super.key, required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: RadioOptionCard._duration,
      curve: Curves.easeOut,
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? accent : onSurface.withValues(alpha: 0.35),
          width: selected ? 2 : 1.5,
        ),
      ),
      child: Center(
        child: AnimatedContainer(
          duration: RadioOptionCard._duration,
          curve: Curves.easeOut,
          width: selected ? 10 : 0,
          height: selected ? 10 : 0,
          decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
        ),
      ),
    );
  }
}
