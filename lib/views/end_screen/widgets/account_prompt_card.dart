import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/end_screen/widgets/soft_ask_card.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return SoftAskCard(
      title: l10n.accountPromptTitle,
      body: l10n.accountPromptBody,
      ctaLabel: l10n.accountPromptCta,
      onCta: onSave,
      onSnooze: onSnooze,
      onDismiss: onDismiss,
    );
  }
}
