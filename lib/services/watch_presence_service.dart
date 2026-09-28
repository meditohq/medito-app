import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';

const _channel = MethodChannel('medito.app/watch_presence');

/// Records whether the user has a paired watch (and the Medito watch app) as
/// GA4 user properties, to size the audience for the watch apps before
/// investing more in them. Native side: WatchPresence in AppDelegate.swift
/// (WCSession) and WatchPresence.kt (installed Wear OS companion apps).
Future<void> reportWatchPresence({FirebaseAnalyticsService? analytics}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  try {
    final status = await _channel
        .invokeMapMethod<String, dynamic>('getStatus')
        .timeout(const Duration(seconds: 10));
    if (status == null) return;
    final service = analytics ?? FirebaseAnalyticsService();
    await service.setUserProperty(
      name: AnalyticsEventConstants.userPropHasPairedWatch,
      value: '${status['paired'] == true}',
    );
    await service.setUserProperty(
      name: AnalyticsEventConstants.userPropWatchAppInstalled,
      value: '${status['appInstalled'] == true}',
    );
  } catch (e) {
    // Missing channel (tests, other platforms) or a timeout: just skip.
    AppLogger.w('WATCH_PRESENCE', 'Could not read watch presence: $e');
  }
}
