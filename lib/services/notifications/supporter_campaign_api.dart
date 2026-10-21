import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uses the user's existing app JWT. Admin/sender credentials never ship in
/// the app. The authenticated header already carries the current FCM token.
class SupporterCampaignApi {
  SupporterCampaignApi(this.client);
  final HttpApiService client;

  Future<Map<String, dynamic>?> sync(
    SharedPreferences prefs, {
    required bool permissionGranted,
    String consistencyBand = 'unknown',
  }) async {
    final response = await client.postRequest(
      'supporter-campaigns/sync',
      body: {
        'push_allowed': permissionGranted,
        'donor_suppressed':
            prefs.getInt(
              SharedPreferenceConstants.lastSuccessfulDonationAtMs,
            ) !=
            null,
        'snooze_until':
            prefs.getInt(SharedPreferenceConstants.donationAskSnoozedUntilMs) ??
            0,
        'reminder_hour': prefs.getInt(SharedPreferenceConstants.savedHours),
        'reminder_minute': prefs.getInt(SharedPreferenceConstants.savedMinutes),
        'utc_offset_min': DateTime.now().timeZoneOffset.inMinutes,
        'consistency_band': consistencyBand,
        if (prefs.getBool(SupporterAppealExperiment.dismissedKey) == true &&
            SupporterAppealExperiment(prefs).assignment?.isServer == true)
          'dismissed_assignment_id': SupporterAppealExperiment(
            prefs,
          ).assignment!.id,
      },
    );
    return response['assignment'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> event(String id, String kind) async {
    final response = await client.postRequest(
      'supporter-campaigns/events',
      body: {'assignment_id': id, 'kind': kind},
    );
    return response['assignment'] as Map<String, dynamic>?;
  }

  /// Preference changes must reach the sender even while Home isn't visible.
  /// Failure leaves local suppression intact and is retried at the next sync.
  static Future<void> updatePreferences(SharedPreferences prefs) async {
    if (isMockMode || !prefs.containsKey('supporter_campaign_registered')) {
      return;
    }
    try {
      await SupporterCampaignApi(HttpApiService()).sync(
        prefs,
        permissionGranted: (await Permission.notification.status).isGranted,
      );
    } catch (_) {
      // Home/resume retries; a donation or settings change must still succeed.
    }
  }
}
