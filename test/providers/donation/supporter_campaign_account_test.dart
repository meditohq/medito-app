import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late SupporterAppealExperiment experiment;
  final now = DateTime.now();
  final data = {
    'id': '11111111-2222-4333-8444-555555555555',
    'campaign_id': 'account-test',
    'arm': 'B',
    'assigned_at': now
        .subtract(const Duration(hours: 1))
        .millisecondsSinceEpoch,
    'expires_at': now.add(const Duration(days: 1)).millisecondsSinceEpoch,
    'announcement': 'Support Medito',
    'cta_title': 'Donate',
    'notification_eligible': true,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.userId: 'first-user',
      SharedPreferenceConstants.isLoggedIn: true,
    });
    prefs = await SharedPreferences.getInstance();
    experiment = SupporterAppealExperiment(prefs);
    expect(
      await experiment.applyServerAssignment(data, userId: 'first-user'),
      isTrue,
    );
  });

  test(
    'switching accounts hides the old card and removes payment attribution',
    () async {
      expect(experiment.paymentMetadata()['appeal_id'], data['id']);
      await prefs.setString(SharedPreferenceConstants.userId, 'second-user');
      expect(experiment.assignment, isNull);
      expect(experiment.showCard(now), isFalse);
      expect(experiment.paymentMetadata(), isEmpty);
      // A late sync response from the old account cannot be adopted by the new one.
      expect(
        await experiment.applyServerAssignment(data, userId: 'first-user'),
        isFalse,
      );
    },
  );

  test(
    'unowned caches from older builds require an authenticated refresh',
    () async {
      final cached =
          jsonDecode(prefs.getString(SupporterAppealExperiment.assignmentKey)!)
              as Map;
      cached.remove('user_id');
      await prefs.setString(
        SupporterAppealExperiment.assignmentKey,
        jsonEncode(cached),
      );
      expect(experiment.paymentMetadata(), isEmpty);
      expect(
        await experiment.applyServerAssignment(data, userId: 'first-user'),
        isTrue,
      );
      expect(experiment.paymentMetadata()['appeal_id'], data['id']);
    },
  );

  test(
    'sign-out clears campaign state and rejects a response still in flight',
    () async {
      await prefs.setBool(SharedPreferenceConstants.isLoggedIn, false);
      expect(experiment.paymentMetadata(), isEmpty);
      expect(
        await experiment.applyServerAssignment(data, userId: 'first-user'),
        isFalse,
      );
      await prefs.setString(SupporterAppealExperiment.pendingOpenKey, '{}');
      await prefs.setBool('supporter_campaign_registered', true);
      await prefs.setBool(SupporterAppealExperiment.dismissedKey, true);
      await SupporterAppealExperiment.clearAccountState(prefs);
      expect(
        prefs.containsKey(SupporterAppealExperiment.assignmentKey),
        isFalse,
      );
      expect(
        prefs.containsKey(SupporterAppealExperiment.pendingOpenKey),
        isFalse,
      );
      expect(prefs.containsKey('supporter_campaign_registered'), isFalse);
      expect(
        prefs.containsKey(SupporterAppealExperiment.dismissedKey),
        isFalse,
      );
    },
  );
}
