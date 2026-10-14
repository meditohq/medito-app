import 'package:flutter/foundation.dart';

import '../constants/strings/analytics_event_constants.dart';
import '../services/analytics/firebase_analytics_service.dart';
import 'logger.dart';
import 'network_type.dart';

/// Logs [AnalyticsEventConstants.appOpen] once per visit, with the
/// connection type. It's the baseline for `network_type` on
/// `audio_session_started`: without it, "most sessions start on wifi" can't be
/// told apart from "most app use is on wifi".
///
/// A visit is a cold start, or a resume after at least [_minBackground] away.
/// That matches GA4's session timeout, so short round-trips (permission
/// dialogs, the payment sheet, a glance at another app) don't count.
class AppOpenTracker {
  AppOpenTracker._();
  static final AppOpenTracker instance = AppOpenTracker._();

  /// Sink for the analytics event. Defaults to Firebase; overridable in tests.
  static Future<void> Function(String name, Map<String, Object> parameters)
  logSink = (name, parameters) =>
      FirebaseAnalyticsService().logEvent(name: name, parameters: parameters);

  /// Clock, overridable in tests.
  static DateTime Function() now = DateTime.now;

  static const _minBackground = Duration(minutes: 30);

  DateTime? _backgroundedAt;

  /// Called once from app init.
  Future<void> onColdStart() => _log('cold');

  /// Called on every lifecycle pause. Only the first one since the last
  /// resume counts, so the away time isn't reset by inactive → paused.
  void onBackgrounded() {
    _backgroundedAt ??= now();
  }

  /// Called on every lifecycle resume. On a cold start there's no recorded
  /// background, so an initial resume can't double-log with [onColdStart].
  Future<void> onForegrounded() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || now().difference(since) < _minBackground) return;
    await _log('resume');
  }

  @visibleForTesting
  void resetForTesting() {
    _backgroundedAt = null;
  }

  Future<void> _log(String launchType) async {
    try {
      await logSink(AnalyticsEventConstants.appOpen, {
        AnalyticsEventConstants.paramLaunchType: launchType,
        AnalyticsEventConstants.paramNetworkType: await NetworkType.current(),
      });
    } catch (e) {
      AppLogger.e('APP_OPEN', 'Failed to log app_open', e);
    }
  }
}
