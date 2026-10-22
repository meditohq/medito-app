import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/currency.dart';
import 'package:medito/widgets/dialogs/medito_dialog_buttons.dart';

/// A persistent acknowledgement shared by every native donation entry point.
/// Web checkout keeps its own confirmation page instead of showing both.
Future<void> showDonationSuccessSheet(
  BuildContext context, {
  required int amount,
  required String currency,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      final theme = Theme.of(context);
      final onSurface = theme.colorScheme.onSurface;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: context.brandAccent,
                  child: Icon(
                    Icons.favorite_outline,
                    size: 32,
                    color: context.onBrandAccent,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text(
                  l10n.thankYouForYourSupport,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.paymentSuccessMessage(
                  currencyAmountToUnitsString(amount, currency),
                  currency.toUpperCase(),
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onSurface,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.donorSupportMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: MeditoDialogPrimaryButton(
                  onPressed: () => Navigator.of(context).pop(),
                  label: l10n.continueText,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
