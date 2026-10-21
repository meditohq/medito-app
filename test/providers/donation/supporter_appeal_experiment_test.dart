import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 20, 12);
  late SharedPreferences prefs;
  late SupporterAppealExperiment experiment;
  LocalAllStats stats({
    int age = 60,
    int last = 1,
    double score = .1,
    int count = 3,
  }) => LocalAllStats.empty().copyWith(
    consistencyScore: score,
    audioCompleted: List.generate(
      count,
      (i) => LocalAudioCompleted(
        timestamp: now
            .subtract(Duration(days: i == 0 ? age : last))
            .millisecondsSinceEpoch,
        id: 'track_$i',
      ),
    ),
  );
  Future<AppealAssignment> enroll(
    String arm, {
    DateTime? at,
    bool notifications = true,
  }) async {
    final seed = List.generate(
      100,
      (i) => i,
    ).firstWhere((i) => ['A', 'B', 'C'][Random(i).nextInt(3)] == arm);
    return (await experiment.enroll(
      stats: stats(),
      now: at ?? now,
      notificationsAllowed: notifications,
      random: Random(seed),
    ))!;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.userId: 'test-user',
    });
    prefs = await SharedPreferences.getInstance();
    experiment = SupporterAppealExperiment(prefs);
  });

  test('established occasional users qualify; new/inactive users do not', () {
    expect(experiment.eligible(stats(score: .01), now), isTrue);
    expect(experiment.eligible(stats(age: 29), now), isFalse);
    expect(experiment.eligible(stats(last: 31), now), isFalse);
    expect(experiment.eligible(stats(count: 2), now), isFalse);
  });

  test('known donations, snoozes and dismissals exclude enrollment', () async {
    await prefs.setInt(SharedPreferenceConstants.lastSuccessfulDonationAtMs, 1);
    expect(experiment.eligible(stats(), now), isFalse);
    await prefs.remove(SharedPreferenceConstants.lastSuccessfulDonationAtMs);
    await prefs.setInt(
      SharedPreferenceConstants.donationAskSnoozedUntilMs,
      now.add(const Duration(days: 1)).millisecondsSinceEpoch,
    );
    expect(experiment.eligible(stats(), now), isFalse);
    await prefs.remove(SharedPreferenceConstants.donationAskSnoozedUntilMs);
    await prefs.setBool(SupporterAppealExperiment.dismissedKey, true);
    expect(experiment.eligible(stats(), now), isFalse);
  });

  test(
    'assignment is sticky, persisted before use and never made by checkout',
    () async {
      expect(experiment.paymentMetadata(now: now), isEmpty);
      expect(
        prefs.containsKey(SupporterAppealExperiment.assignmentKey),
        isFalse,
      );
      final a = await enroll('B');
      final again = await enroll('C');
      expect(again.arm, 'B');
      expect(again.id, a.id);
      expect(again.consistency, 'under_25');
      expect(experiment.assignment!.id, a.id);
    },
  );

  test(
    'malformed stored assignment fails closed without re-randomising',
    () async {
      await prefs.setString(SupporterAppealExperiment.assignmentKey, 'broken');
      expect(
        await experiment.enroll(
          stats: stats(),
          now: now,
          notificationsAllowed: true,
        ),
        isNull,
      );
      expect(experiment.paymentMetadata(now: now), isEmpty);
    },
  );

  test('control is tagged in payments but never shows a card', () async {
    await enroll('A');
    expect(experiment.showCard(now), isFalse);
    expect(
      experiment.paymentMetadata(now: now)[SupporterAppealExperiment.name],
      'A',
    );
    expect(
      experiment
          .paymentMetadata(now: now)
          .containsKey('appeal_notification_click_id'),
      isFalse,
    );
  });

  test(
    'card has a seven-day window and never restarts on a new visit',
    () async {
      await enroll('B');
      expect(experiment.showCard(now), isTrue);
      expect(experiment.showCard(now.add(const Duration(days: 7))), isFalse);
      await enroll('C', at: now.add(const Duration(days: 30)));
      expect(experiment.showCard(now.add(const Duration(days: 30))), isFalse);
    },
  );

  test(
    'notification uses June copy and cannot deep-link straight to payment',
    () async {
      final a = await enroll('C');
      final payload = jsonDecode(experiment.notificationPayload(a));
      expect(payload['source'], SupporterAppealExperiment.name);
      expect(payload['type'], isNull);
      expect(payload['path'], isNull);
      expect(
        SupporterAppealExperiment.notificationBody,
        'Just a few minutes of stillness can change your whole day. Ready to breathe?',
      );
      expect(
        SupporterAppealExperiment.announcementText.contains('10,000'),
        isFalse,
      );
    },
  );

  test(
    'cold/warm duplicate tap is counted once and joins later payments',
    () async {
      final a = await enroll('C');
      final payload =
          jsonDecode(experiment.notificationPayload(a)) as Map<String, dynamic>;
      final tappedAt = now.add(const Duration(days: 1));
      final first = await experiment.recordNotificationTap(payload, tappedAt);
      expect(first!['appeal_notification_click_id'], a.id);
      expect(await experiment.recordNotificationTap(payload, tappedAt), isNull);
      expect(
        experiment.paymentMetadata(
          now: tappedAt.add(const Duration(days: 2)),
        )['appeal_notification_click_id'],
        a.id,
      );
      expect(
        experiment
            .paymentMetadata(now: tappedAt.add(const Duration(days: 8)))
            .containsKey('appeal_notification_click_id'),
        isFalse,
      );
    },
  );

  test(
    'normal reminders, forged arms and expired taps cannot claim appeal credit',
    () async {
      final a = await enroll('C');
      expect(
        await experiment.recordNotificationTap({
          'source': 'local_reminder',
        }, now),
        isNull,
      );
      final payload =
          jsonDecode(experiment.notificationPayload(a)) as Map<String, dynamic>;
      expect(
        await experiment.recordNotificationTap({
          ...payload,
          'variant_id': 'B',
        }, now),
        isNull,
      );
      expect(
        await experiment.recordNotificationTap(
          payload,
          now.add(const Duration(days: 8)),
        ),
        isNull,
      );
      expect(prefs.containsKey(SupporterAppealExperiment.tapKey), isFalse);
    },
  );

  test(
    'CTA UTMs do not overwrite acquisition UTMs or retain stale click snapshots',
    () async {
      await enroll('B');
      await prefs.setString('utm_source', 'google');
      final tags = experiment.ctaMetadata(now: now);
      expect(tags['utm_campaign'], SupporterAppealExperiment.campaign);
      expect(tags['utm_content'], 'B');
      expect(tags.containsKey('appeal_notification_click_id'), isFalse);
      expect(
        experiment.paymentMetadata(now: now).containsKey('utm_source'),
        isFalse,
      );
      expect(prefs.getString('utm_source'), 'google');
    },
  );

  test(
    'tap entry point requests Home once, before payment attribution is read',
    () async {
      final a = await enroll('C', at: DateTime.now());
      final payload =
          jsonDecode(experiment.notificationPayload(a)) as Map<String, dynamic>;
      final baseline = SupporterAppealRuntime.homeRequested.value;
      await SupporterAppealRuntime.recordOpen(payload);
      expect(SupporterAppealRuntime.homeRequested.value, baseline + 1);
      expect(SupporterAppealRuntime.consumeHomeRequest(), isTrue);
      expect(SupporterAppealRuntime.consumeHomeRequest(), isFalse);
      expect(
        experiment.paymentMetadata()['appeal_notification_click_id'],
        a.id,
      );
      await SupporterAppealRuntime.recordOpen(payload);
      expect(SupporterAppealRuntime.homeRequested.value, baseline + 1);
      expect(SupporterAppealRuntime.consumeHomeRequest(), isFalse);
    },
  );

  test(
    'server assignments use persistent IDs, dynamic copy and B/C tap attribution',
    () async {
      final data = {
        'id': '11111111-2222-4333-8444-555555555555',
        'campaign_id': 'remote-campaign',
        'arm': 'B',
        'assigned_at': now.millisecondsSinceEpoch,
        'expires_at': now.add(const Duration(days: 2)).millisecondsSinceEpoch,
        'notification_eligible': true,
        'consistency_band': 'under_25',
        'announcement': 'Server announcement',
        'cta_title': 'Support Medito',
      };
      expect(
        await experiment.applyServerAssignment(data, userId: 'test-user'),
        isTrue,
      );
      final a = experiment.assignment!;
      expect(a.isServer, isTrue);
      expect(a.id, data['id']);
      expect(a.announcement, 'Server announcement');
      expect(experiment.showCard(now.add(const Duration(days: 3))), isFalse);
      expect(experiment.ctaMetadata()['utm_campaign'], 'remote-campaign');
      expect(
        experiment.paymentMetadata(now: now)['appeal_campaign_id'],
        'remote-campaign',
      );
      final payload =
          jsonDecode(experiment.notificationPayload(a)) as Map<String, dynamic>;
      expect(
        await experiment.recordNotificationTap(
          payload,
          now.add(const Duration(minutes: 1)),
        ),
        isNotNull,
      );
      await prefs.setBool(SupporterAppealExperiment.dismissedKey, true);
      await experiment.applyServerAssignment(data, userId: 'test-user');
      expect(prefs.getBool(SupporterAppealExperiment.dismissedKey), isTrue);
      expect(prefs.containsKey(SupporterAppealExperiment.tapKey), isTrue);
      expect(
        await experiment.applyServerAssignment({
          ...data,
          'id': 'bad-id',
        }, userId: 'test-user'),
        isFalse,
      );
      expect(experiment.assignment!.id, a.id);
    },
  );
}
