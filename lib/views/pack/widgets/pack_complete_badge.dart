import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';

/// Read-only tick for a pack whose sessions are all complete. Matches the
/// filled state of a track row's completion toggle.
class PackCompleteBadge extends StatelessWidget {
  const PackCompleteBadge({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context)!.completed,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.brandPurple,
          ),
          // Accent's own foreground: the accent is near-white in dark mode.
          child: Icon(
            Icons.check,
            size: size * 2 / 3,
            color: context.onBrandPurple,
          ),
        ),
      ),
    );
  }
}
