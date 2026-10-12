import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';

import 'end_screen_card.dart';

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
    return EndScreenCard(
      inverted: true,
      title: l10n.thankYouForYourSupport,
      body: l10n.donorSupportMessage,
    );
  }
}
