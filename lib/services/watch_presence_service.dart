import 'dart:async';
import 'dart:io';

import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/src/watch_presence_pigeon.g.dart';
import 'package:medito/utils/logger.dart';

/// Records whether the user has a paired watch (and the Medito watch app) as
/// GA4 user properties, to size the audience for the watch apps before
/// investing more in them. Native side: WatchPresence in AppDelegate.swift
/// (WCSession) and WatchPresence.kt (installed Wear OS companion apps).
Future<void> reportWatchPresence({FirebaseAnalyticsService? analytics}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  try {
    final status = await WatchPresenceApi().getStatus().timeout(
      const Duration(seconds: 10),
    );
    final service = analytics ?? FirebaseAnalyticsService();
    await service.setUserProperty(
      name: AnalyticsEventConstants.userPropHasPairedWatch,
      value: '${status.paired}',
    );
    await service.setUserProperty(
      name: AnalyticsEventConstants.userPropWatchAppInstalled,
      value: '${status.appInstalled}',
    );
  } catch (e) {
    // Missing channel (tests, other platforms), failed WCSession activation
    // or a timeout: just skip.
    AppLogger.w('WATCH_PRESENCE', 'Could not read watch presence: $e');
  }
}
