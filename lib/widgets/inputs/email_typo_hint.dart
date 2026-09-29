import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/email_typo.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

const emailTypoHintKey = Key('email_typo_hint');
const emailTypoDialogKey = Key('email_typo_dialog');

/// "Did you mean …@gmail.com?" under an email field. Rebuilds from
/// [controller] and renders nothing until [suggestEmailCorrection] finds a
/// likely domain typo; tapping swaps the fix in. Never blocks submission.
class EmailTypoHint extends StatelessWidget {
  const EmailTypoHint({
    super.key,
    required this.controller,
    this.onAccepted,
    this.color,
  });

  final TextEditingController controller;

  /// Called after the corrected address is written into [controller], for
  /// callers whose validation runs from `onChanged` (which a programmatic
  /// edit does not fire).
  final VoidCallback? onAccepted;

  /// Text colour on surfaces that differ from the page; defaults to primary.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final suggestion = suggestEmailCorrection(value.text);
        if (suggestion == null) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context)!;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: InkWell(
            key: emailTypoHintKey,
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              controller.value = TextEditingValue(
                text: suggestion,
                selection: TextSelection.collapsed(offset: suggestion.length),
              );
              onAccepted?.call();
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text.rich(
                emailSuggestionSpan(l10n, value.text, suggestion),
                style: TextStyle(
                  fontFamily: googleSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.underline,
                  color: color ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The localized sentence with the corrected labels in bold. The address
/// goes in via a sentinel so translations keep their own word order.
TextSpan emailSuggestionSpan(
  AppLocalizations l10n,
  String typed,
  String suggestion,
) {
  const sentinel = '\u0000';
  final parts = l10n.emailTypoSuggestion(sentinel).split(sentinel);
  return TextSpan(
    children: [
      TextSpan(text: parts.first),
      for (final segment in emailCorrectionSegments(typed, suggestion))
        TextSpan(
          text: segment.text,
          style: segment.changed
              ? const TextStyle(fontWeight: FontWeight.w700)
              : null,
        ),
      if (parts.length > 1) TextSpan(text: parts.sublist(1).join()),
    ],
  );
}

/// Last check before an email is used: if the hint is still showing, asks
/// once "Did you mean …?" so a typo never silently reaches the OTP or Stripe
/// receipt. Keeps one instance per screen so "Keep mine" sticks for that
/// address instead of re-asking on every retry.
class EmailTypoConfirmation {
  String? _kept;

  /// Resolves to false when the dialog is dismissed (stay on the form),
  /// true to go ahead. "Use this" writes the fix into [controller] first,
  /// then calls [onAccepted].
  Future<bool> confirm(
    BuildContext context,
    TextEditingController controller, {
    VoidCallback? onAccepted,
  }) async {
    final typed = controller.text.trim();
    final suggestion = suggestEmailCorrection(typed);
    if (suggestion == null || typed == _kept) return true;

    final l10n = AppLocalizations.of(context)!;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFamily: googleSans,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.75),
    );
    final choice = await showDialog<bool>(
      context: context,
      builder: (context) => MeditoDialog(
        title: l10n.emailTypoDialogTitle,
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${l10n.emailTypoDialogTyped(typed)}\n'),
              emailSuggestionSpan(l10n, typed, suggestion),
            ],
          ),
          key: emailTypoDialogKey,
          style: bodyStyle,
        ),
        actions: [
          MeditoDialogSecondaryButton(
            label: l10n.emailTypoKeepTyped,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          MeditoDialogPrimaryButton(
            label: l10n.emailTypoUseSuggestion,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (choice == null) return false;
    if (choice) {
      controller.value = TextEditingValue(
        text: suggestion,
        selection: TextSelection.collapsed(offset: suggestion.length),
      );
      onAccepted?.call();
    } else {
      _kept = typed;
    }
    return true;
  }
}
