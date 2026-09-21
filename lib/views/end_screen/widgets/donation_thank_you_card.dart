import 'package:flutter/material.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';

import '../../home/widgets/home_gradient_border.dart';

/// Donor-only thank-you shown in place of the donation ask for the snooze
/// window after a completed donation.
///
/// Deliberately has NO call to action: the old "Donate again" button drew
/// ~7 repeat gifts a month (Aug–Sep 2026) and read as if the app hadn't
/// noticed the person already gives. The regular ask returns when the window
/// ends. "Hide for now" snoozers never see this — they get no card at all.
class DonationThankYouCard extends StatelessWidget {
  const DonationThankYouCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HomeGradientBorder(
      backgroundColor: context.brandPurple,
      borderRadius: 14,
      borderWidth: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.thankYouForYourSupport,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: googleSans,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: context.onBrandPurple,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.donorSupportMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: context.onBrandPurple.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
