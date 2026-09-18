import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/home_gradient_border.dart';
import 'package:medito/widgets/medito_icon.dart';

/// End-screen soft-ask inviting an anonymous user to attach an email to their
/// account so their streak and history survive a reinstall or a new phone.
///
/// Visual only — gating, analytics and navigation live in the end screen. Kept
/// standalone so it can be previewed and tested without the end screen's
/// provider graph.
class AccountPromptCard extends StatelessWidget {
  const AccountPromptCard({
    super.key,
    required this.onSave,
    required this.onSnooze,
    required this.onDismiss,
  });

  /// Primary CTA — open the sign-in sheet to link an email.
  final VoidCallback onSave;

  /// "Not now" — soft dismiss (snooze).
  final VoidCallback onSnooze;

  /// ✕ — permanent dismiss.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: 16,
      ),
      child: HomeGradientBorder(
        backgroundColor: Theme.of(context).cardColor,
        borderRadius: 14,
        borderWidth: 0.5,
        child: Padding(
          padding: const EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: 4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  MeditoIcon(
                    assetName: MeditoIcons.heart,
                    size: 24,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.accountPromptTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.dismiss,
                    icon: MeditoIcon(
                      assetName: MeditoIcons.xmark,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: onDismiss,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.accountPromptBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onSave,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.accountPromptCta,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.onBrandPurple,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
