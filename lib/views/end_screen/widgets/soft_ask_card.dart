import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';

import 'end_screen_card.dart';

/// Shared layout for the end-screen soft-asks (reminders, account): an
/// [EndScreenCard] with the ✕ in the corner, a full-width CTA and "Not now".
class SoftAskCard extends StatelessWidget {
  const SoftAskCard({
    super.key,
    required this.title,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    required this.onSnooze,
    required this.onDismiss,
  });

  final String title;
  final String body;
  final String ctaLabel;

  /// Primary CTA.
  final VoidCallback onCta;

  /// "Not now" — soft dismiss (snooze).
  final VoidCallback onSnooze;

  /// ✕ — permanent dismiss.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: 16,
      ),
      child: EndScreenCard(
        title: title,
        body: body,
        corner: EndScreenCardCorner(
          icon: MeditoIcons.xmark,
          tooltip: AppLocalizations.of(context)!.dontShowAgain,
          onPressed: onDismiss,
        ),
        bottomPadding: 8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: onCta,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                ctaLabel,
                textAlign: TextAlign.center,
                style: EndScreenCard.buttonStyle(
                  context,
                  color: context.onBrandAccent,
                ),
              ),
            ),
            TextButton(
              onPressed: onSnooze,
              child: Text(
                AppLocalizations.of(context)!.notNow,
                style: EndScreenCard.secondaryStyle(
                  context,
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
