import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/http/http_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/donation/donation_snooze_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:medito/services/notifications/local_notifications.dart';
import 'package:medito/services/notifications/notification_timing.dart';
import 'package:medito/services/notifications/supporter_campaign_api.dart';
import 'package:medito/utils/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supporter_appeal_experiment.dart';

final supporterCampaignApiProvider = Provider<SupporterCampaignApi>(
  (ref) => SupporterCampaignApi(HttpApiService()),
);

final supporterAppealProvider = FutureProvider<AppealAssignment?>((ref) async {
  if (isMockMode || (!Platform.isIOS && !Platform.isAndroid)) return null;
  ref.watch(donationSnoozeProvider);
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  final prefs = ref.read(sharedPreferencesProvider);
  // Migration only: cancel the old prototype's local appeal. No local campaign
  // notifications are scheduled anywhere in this provider.
  await LocalNotifications.cancelSafely(
    SupporterAppealExperiment.notificationId,
  );
  if (!SupporterAppealExperiment.enabled) return null;
  try {
    final stats = await ref.watch(statsProvider.future);
    if (!ref.mounted) return null;
    final granted = (await Permission.notification.status).isGranted;
    if (granted && Platform.isAndroid) {
      await LocalNotifications.ensureInitialized();
      await LocalNotifications.plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              'medito_supporter_appeal',
              'Supporter updates',
              description: 'Optional supporter updates and donation requests',
              importance: Importance.defaultImportance,
            ),
          );
    }
    final userId = prefs.getString(SharedPreferenceConstants.userId);
    if (userId == null) return null;
    final api = ref.read(supporterCampaignApiProvider);
    final data = await api.sync(
      prefs,
      permissionGranted: granted,
      consistencyBand: stats.consistencyScore < .25
          ? 'under_25'
          : stats.consistencyScore < .5
          ? '25_to_50'
          : '50_plus',
    );
    if (!ref.mounted ||
        prefs.getString(SharedPreferenceConstants.userId) != userId ||
        prefs.getBool(SharedPreferenceConstants.isLoggedIn) == false) {
      return null;
    }
    await prefs.setBool('supporter_campaign_registered', true);
    // Accepted-message opens can still reconcile after a campaign is paused,
    // even though sync correctly withholds its announcement card.
    await SupporterAppealRuntime.retryPendingOpen(prefs, api);
    if (data == null) return null;
    final experiment = SupporterAppealExperiment(prefs);
    final previousId = experiment.assignment?.id;
    if (!await experiment.applyServerAssignment(data, userId: userId)) {
      return null;
    }
    if (previousId != experiment.assignment?.id) {
      await SupporterAppealRuntime.log('appeal_assignment_observed', prefs);
    }
    return experiment.assignment;
  } catch (e) {
    AppLogger.w(
      'SUPPORTER_APPEAL',
      'Campaign sync unavailable; keeping the usual Home content',
    );
    return null;
  }
});

class SupporterAppealRuntime {
  SupporterAppealRuntime._();
  static final homeRequested = ValueNotifier<int>(0);
  static bool _pendingHome = false;
  static final _opening = <String>{};
  static const _pendingOpenKey = SupporterAppealExperiment.pendingOpenKey;

  static bool consumeHomeRequest() {
    final pending = _pendingHome;
    _pendingHome = false;
    return pending;
  }

  static Future<void> log(
    String event,
    SharedPreferences prefs, {
    Map<String, Object> timing = const {},
  }) => FirebaseAnalyticsService().logEvent(
    name: event,
    parameters: {
      ...SupporterAppealExperiment(prefs).paymentMetadata(),
      'campaign_id':
          SupporterAppealExperiment(prefs).assignment?.campaignId ??
          SupporterAppealExperiment.campaign,
      ...timing,
      if (prefs.getString(SharedPreferenceConstants.userId)
          case final String id)
        'medito_user_id': id,
    },
  );

  static Future<void> report(String kind, SharedPreferences prefs) async {
    final a = SupporterAppealExperiment(prefs).assignment;
    if (a == null || !a.isServer || isMockMode) return;
    if (kind != 'dismissed' &&
        prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ==
            false) {
      return;
    }
    try {
      await SupporterCampaignApi(HttpApiService()).event(a.id, kind);
    } catch (_) {
      /* Next preference sync preserves local suppression. */
    }
  }

  static Future<void> retryPendingOpen(
    SharedPreferences prefs,
    SupporterCampaignApi api,
  ) async {
    final raw = prefs.getString(_pendingOpenKey);
    if (raw == null) return;
    Future<void> discard() async {
      // A different account/tap may have replaced this entry during the request.
      if (prefs.getString(_pendingOpenKey) == raw) {
        await prefs.remove(_pendingOpenKey);
      }
    }

    if (prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ==
        false) {
      await discard();
      return;
    }
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final userId = prefs.getString(SharedPreferenceConstants.userId);
      if (userId == null ||
          saved['user_id'] != userId ||
          prefs.getBool(SharedPreferenceConstants.isLoggedIn) == false) {
        await discard();
        return;
      }
      final at = DateTime.fromMillisecondsSinceEpoch(saved['at'] as int);
      if (DateTime.now().difference(at) >
          SupporterAppealExperiment.cardWindow) {
        await discard();
        return;
      }
      final payload = saved['payload'] as Map<String, dynamic>;
      final data = await api.event(payload['appeal_id'] as String, 'opened');
      final experiment = SupporterAppealExperiment(prefs);
      if (data != null &&
          data['id'] == payload['appeal_id'] &&
          await experiment.applyServerAssignment(data, userId: userId)) {
        if (await experiment.recordNotificationTap(payload, at) != null) {
          await log(
            'appeal_notification_opened',
            prefs,
            timing: NotificationTiming.opened(payload, at),
          );
        }
      }
      await discard();
    } catch (_) {
      /* Retry this same event at the next app sync. */
    }
  }

  static Future<void> recordOpen(Map<String, dynamic>? payload) async {
    if (payload?['source'] != SupporterAppealExperiment.name) return;
    final id = payload?['appeal_id'];
    if (id is! String || !_opening.add(id)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final experiment = SupporterAppealExperiment(prefs);
      final cached = experiment.assignment;
      final at = DateTime.now();
      // Keep the in-memory preview/legacy payload tests valid; no local send
      // path remains in production.
      if (cached != null && !cached.isServer && cached.id == id) {
        if (await experiment.recordNotificationTap(payload, at) == null) return;
        _pendingHome = true;
        homeRequested.value++;
        await log(
          'appeal_notification_opened',
          prefs,
          timing: NotificationTiming.opened(payload, at),
        );
        return;
      }
      if (!RegExp(
        r'^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$',
      ).hasMatch(id)) {
        return;
      }
      if (cached?.id == id &&
          prefs.containsKey(SupporterAppealExperiment.tapKey)) {
        return;
      }
      _pendingHome = true;
      homeRequested.value++;
      if (prefs.getBool(SharedPreferenceConstants.analyticsFirebaseEnabled) ==
          false) {
        return;
      }
      await prefs.setString(
        _pendingOpenKey,
        jsonEncode({
          'payload': payload,
          'at': at.millisecondsSinceEpoch,
          'user_id': prefs.getString(SharedPreferenceConstants.userId),
        }),
      );
      await retryPendingOpen(prefs, SupporterCampaignApi(HttpApiService()));
    } finally {
      _opening.remove(id);
    }
  }
}
