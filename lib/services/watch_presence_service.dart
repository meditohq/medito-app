import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Whether Settings should offer the Medito watch app: a watch is paired but
/// the app isn't on it. False when the state can't be read or on other
/// platforms (incl. the web widget previewer).
final watchInstallPromptProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) return false;
  try {
    final status = await WatchPresenceApi().getStatus().timeout(
      const Duration(seconds: 10),
    );
    return status.paired && !status.appInstalled;
  } catch (e) {
    AppLogger.w('WATCH_PRESENCE', 'Could not read watch presence: $e');
    return false;
  }
});
