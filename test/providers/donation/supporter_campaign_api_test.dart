import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/notifications/supporter_campaign_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends HttpApiService {
  _Client() : super.internal();
  final calls = <Map<String, dynamic>>[];
  Map<String, dynamic>? assignment;
  @override
  Future<Map<String, dynamic>> postRequest(String path, {dynamic body}) async {
    calls.add({'path': path, 'body': body});
    return {'assignment': assignment};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> serverAssignment(DateTime now) => {
    'id': '11111111-2222-4333-8444-555555555555',
    'campaign_id': 'live-campaign',
    'arm': 'B',
    'assigned_at': now
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch,
    'expires_at': now.add(const Duration(days: 2)).millisecondsSinceEpoch,
    'notification_eligible': true,
    'consistency_band': '50_plus',
    'announcement': 'Server copy',
    'cta_title': 'Donate now',
  };
  test(
    'sync sends preferences and reminder snapshot, never admin credentials or local history',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.dailyReminderEnabled: true,
        SharedPreferenceConstants.savedHours: 18,
        SharedPreferenceConstants.savedMinutes: 30,
        SharedPreferenceConstants.lastSuccessfulDonationAtMs: 1,
      });
      final prefs = await SharedPreferences.getInstance(), client = _Client();
      final api = SupporterCampaignApi(client);
      await api.sync(
        prefs,
        permissionGranted: true,
        consistencyBand: '50_plus',
      );
      final body = client.calls.single['body'] as Map;
      expect(body['push_allowed'], isTrue);
      expect(body['donor_suppressed'], isTrue);
      expect(body['reminder_hour'], 18);
      expect(body['reminder_minute'], 30);
      expect(body['consistency_band'], '50_plus');
      expect(body.containsKey('audio_completed'), isFalse);
      expect(body.containsKey('admin_token'), isFalse);
      await api.sync(prefs, permissionGranted: false);
      expect((client.calls.last['body'] as Map)['push_allowed'], isFalse);
    },
  );
  test(
    'an offline tap is reconciled once with the authenticated assignment and original tap time',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(), client = _Client();
      final now = DateTime.now(), at = now.subtract(const Duration(minutes: 5));
      client.assignment = serverAssignment(now);
      final payload = {
        'source': SupporterAppealExperiment.name,
        'campaign_id': 'live-campaign',
        'variant_id': 'B',
        'appeal_id': client.assignment!['id'],
        'scheduled_at':
            '${at.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch ~/ 1000}',
      };
      await prefs.setString(
        'supporter_campaign_pending_open',
        jsonEncode({'payload': payload, 'at': at.millisecondsSinceEpoch}),
      );
      final api = SupporterCampaignApi(client);
      await SupporterAppealRuntime.retryPendingOpen(prefs, api);
      await SupporterAppealRuntime.retryPendingOpen(prefs, api);
      expect(client.calls, hasLength(1));
      expect(client.calls.single['path'], 'supporter-campaigns/events');
      final metadata = SupporterAppealExperiment(prefs).paymentMetadata();
      expect(
        metadata['appeal_notification_click_id'],
        client.assignment!['id'],
      );
      expect(metadata['appeal_campaign_id'], 'live-campaign');
      expect(
        metadata['appeal_notification_tapped_at'],
        '${at.millisecondsSinceEpoch ~/ 1000}',
      );
    },
  );
  test(
    'a pending tap is discarded when analytics consent is disabled before retry',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.analyticsFirebaseEnabled: false,
        'supporter_campaign_pending_open': jsonEncode({
          'payload': {'appeal_id': '11111111-2222-4333-8444-555555555555'},
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      });
      final prefs = await SharedPreferences.getInstance(), client = _Client();
      await SupporterAppealRuntime.retryPendingOpen(
        prefs,
        SupporterCampaignApi(client),
      );
      expect(client.calls, isEmpty);
      expect(prefs.containsKey('supporter_campaign_pending_open'), isFalse);
      expect(prefs.containsKey(SupporterAppealExperiment.tapKey), isFalse);
    },
  );
  test(
    'a backend response for a different assignment cannot claim the notification click',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance(), client = _Client();
      client.assignment = serverAssignment(DateTime.now());
      await prefs.setString(
        'supporter_campaign_pending_open',
        jsonEncode({
          'payload': {'appeal_id': 'another-id'},
          'at': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      await SupporterAppealRuntime.retryPendingOpen(
        prefs,
        SupporterCampaignApi(client),
      );
      expect(prefs.containsKey(SupporterAppealExperiment.tapKey), isFalse);
      expect(
        prefs.containsKey(SupporterAppealExperiment.assignmentKey),
        isFalse,
      );
    },
  );
}
