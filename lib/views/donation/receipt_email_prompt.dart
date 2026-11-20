import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/theme/medito_text.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stripe/payment_providers.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/receipt_email.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';

const receiptEmailPromptFieldKey = Key('receipt_email_prompt_field');

/// After an Apple Pay donation made without an address on the page: confirm
/// the Stripe Customer got one from the sheet, and ask the donor if not.
///
/// Shared by the native donation page and the end-screen card, the two places
/// where Apple Pay supplies the email. The API fills the Customer from the
/// charge as part of this call, so it does not depend on the webhook having
/// run yet. Every failure is swallowed — the gift has already succeeded, and
/// an API without this endpoint yet must not hold the donor on the page.
Future<void> ensureReceiptEmail(
  BuildContext context,
  WidgetRef ref, {
  required String logTag,
}) async {
  try {
    final intent = ref.read(paymentStateProvider).paymentIntent;
    if (intent == null) return;
    final client = ref.read(donationServiceProvider);
    Future<bool> customerHasEmail([String? email]) async {
      final response = await client
          .postRequest(
            HTTPConstants.receiptEmail,
            body: {
              'paymentIntentId': intent.id,
              'clientSecret': intent.clientSecret,
              'email': ?email,
            },
          )
          .timeout(const Duration(seconds: 8));
      final data = response['data'];
      return data is Map && data['hasEmail'] == true;
    }

    if (await customerHasEmail()) return;
    if (!context.mounted) return;
    final email = await showReceiptEmailPrompt(context);
    if (email == null) {
      AppLogger.w(logTag, 'Donor skipped the receipt email prompt');
      return;
    }
    // A 200 can still say no (payment without a customer or charge, or a
    // deleted customer). Only remember the address once Stripe has it.
    if (!await customerHasEmail(email)) {
      AppLogger.w(logTag, 'Receipt email was not saved to the customer');
      return;
    }
    if (!context.mounted) return;
    await ReceiptEmail.save(ref.read(sharedPreferencesProvider), email);
  } catch (e) {
    AppLogger.w(logTag, 'Could not confirm the receipt email: $e');
  }
}

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
