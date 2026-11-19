import 'package:flutter/material.dart';
import 'package:medito/constants/theme/medito_text.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';

const receiptEmailPromptFieldKey = Key('receipt_email_prompt_field');

/// Asks a donor who has just paid for the address their receipt should go to.
///
/// Only for the rare payment where the Apple Pay sheet was meant to supply the
/// email and none reached Stripe: without one the donor gets no receipt and
/// cannot open the billing portal to manage a recurring gift.
///
/// Returns the address, or null if the donor skipped.
Future<String?> showReceiptEmailPrompt(BuildContext context) {
  return showDialog<String>(
    context: context,
    useRootNavigator: true,
    builder: (_) => const _ReceiptEmailDialog(),
  );
}

class _ReceiptEmailDialog extends StatefulWidget {
  const _ReceiptEmailDialog();

  @override
  State<_ReceiptEmailDialog> createState() => _ReceiptEmailDialogState();
}

class _ReceiptEmailDialogState extends State<_ReceiptEmailDialog> {
  // Same permissive pattern as the donation page: a false reject costs more
  // than a typo.
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$');
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final email = _controller.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      final l10n = AppLocalizations.of(context)!;
      setState(
        () => _error = email.isEmpty
            ? l10n.donationEmailRequired
            : l10n.donationEmailInvalid,
      );
      return;
    }
    Navigator.of(context).pop(email);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.donationReceiptEmailTitle, style: context.text.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.donationReceiptEmailBody,
            style: context.text.body.copyWith(
              color: onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          MeditoTextField(
            fieldKey: receiptEmailPromptFieldKey,
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            autocorrect: false,
            labelText: l10n.donationEmailLabel,
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.skip),
        ),
        MeditoDialogPrimaryButton(label: l10n.save, onPressed: _save),
      ],
    );
  }
}
