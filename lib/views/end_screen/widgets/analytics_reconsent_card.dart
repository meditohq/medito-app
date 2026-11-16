import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

import 'end_screen_card.dart';

/// End-screen ask to turn usage stats back on, for iOS users whose opt-out was
/// most likely written by the old App Tracking Transparency path.
///
/// An [EndScreenCard] like the other soft-asks in this slot, but the two answers are
/// equal-weight buttons with no ✕ or "Not now": this is a consent question, so
/// "no" has to be exactly as easy as "yes".
///
/// The card itself stays to a title and one line so it doesn't crowd the end
/// screen; why stats were off, what they record and where to change them are
/// one tap away behind the corner ? icon, as on the donation card.
///
/// Visual only — gating, analytics and the SDK switch live in the end screen.
class AnalyticsReconsentCard extends StatelessWidget {
  const AnalyticsReconsentCard({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: onSurface,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      side: BorderSide(color: onSurface.withValues(alpha: 0.3)),
    );
    final buttonTextStyle = EndScreenCard.buttonStyle(
      context,
      color: onSurface,
    );

    return Padding(
      padding: const EdgeInsets.only(
        left: padding16,
        right: padding16,
        bottom: 16,
      ),
      child: EndScreenCard(
        title: l10n.analyticsReconsentTitle,
        body: l10n.analyticsReconsentBody,
        corner: EndScreenCardCorner(
          icon: MeditoIcons.help,
          tooltip: l10n.analyticsReconsentInfoTitle,
          onPressed: () => _showInfo(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onDecline,
                style: buttonStyle,
                child: Text(
                  l10n.analyticsReconsentDecline,
                  textAlign: TextAlign.center,
                  style: buttonTextStyle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: onAccept,
                style: buttonStyle,
                child: Text(
                  l10n.analyticsReconsentAccept,
                  textAlign: TextAlign.center,
                  style: buttonTextStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => MeditoDialog(
        title: l10n.analyticsReconsentInfoTitle,
        content: SingleChildScrollView(
          child: MeditoDialogBody(l10n.analyticsReconsentInfoBody),
        ),
        actions: [
          MeditoDialogPrimaryButton(
            label: l10n.close,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }
}
