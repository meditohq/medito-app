import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

/// Shared layout for the end-screen soft-asks (reminders, account). Mirrors the
/// donation card below it — left-aligned title with the ✕ in the corner, body,
/// then a full-width CTA — so the stacked cards read as one family.
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
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: 16,
      ),
      child: HomeGradientBorder(
        backgroundColor: theme.cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        title,
                        style: context.text.title.copyWith(color: onSurface),
                      ),
                    ),
                  ),
                  // Hides the card for good ("Not now" below only snoozes),
                  // so it says so rather than just "Dismiss". Standard
                  // density keeps the padded tap target at 48pt.
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.dontShowAgain,
                    icon: MeditoIcon(
                      assetName: MeditoIcons.xmark,
                      size: 20,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: context.text.body.copyWith(
                        color: onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onCta,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          ctaLabel,
                          textAlign: TextAlign.center,
                          style: context.text.subtitle.copyWith(
                            color: context.onBrandAccent,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: onSnooze,
                        child: Text(
                          AppLocalizations.of(context)!.notNow,
                          style: context.text.label.copyWith(
                            color: onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
