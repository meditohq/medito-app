import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/notifications/supporter_campaign_api.dart';

/// Separate explicit consent for campaign pushes. Existing daily reminders and
/// OS notification permission never switch this on, including on app upgrade.
class SupporterNotificationsTile extends ConsumerStatefulWidget {
  const SupporterNotificationsTile({super.key});

  @override
  ConsumerState<SupporterNotificationsTile> createState() =>
      _SupporterNotificationsTileState();
}

class _SupporterNotificationsTileState
    extends ConsumerState<SupporterNotificationsTile> {
  bool _busy = false;

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    final prefs = ref.read(sharedPreferencesProvider);
    try {
      await prefs.setBool(
        SharedPreferenceConstants.supporterCampaignPushOptIn,
        enabled,
      );
      if (!mounted) return;
      ref.invalidate(supporterAppealProvider);
      // Suppression reaches the sender even when Home is not visible. Home
      // and resume retry if this request fails while the device is offline.
      await SupporterCampaignApi.updatePreferences(prefs);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SwitchListTile.adaptive(
        title: Text(l10n.supporterNotificationsTitle),
        subtitle: Text(l10n.supporterNotificationsDescription),
        value:
            prefs.getBool(
              SharedPreferenceConstants.supporterCampaignPushOptIn,
            ) ??
            false,
        onChanged: _busy ? null : _setEnabled,
      ),
    );
  }
}
