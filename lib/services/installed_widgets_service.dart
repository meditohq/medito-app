import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/logger.dart';

/// Records which home-screen widgets the user has placed as a GA4 user
/// property. Taps alone (home_widget_tapped) miss widgets that sit on the
/// home screen as a passive reminder and are never tapped.
Future<void> reportInstalledHomeWidgets({
  FirebaseAnalyticsService? analytics,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  try {
    final widgets = await HomeWidget.getInstalledWidgets().timeout(
      const Duration(seconds: 10),
    );
    final service = analytics ?? FirebaseAnalyticsService();
    await service.setUserProperty(
      name: AnalyticsEventConstants.userPropHomeWidgets,
      value: homeWidgetsPropertyValue(widgets),
    );
  } catch (e) {
    // Missing channel (tests, other platforms) or a timeout: just skip.
    AppLogger.w('WIDGET', 'Could not read installed widgets: $e');
  }
}

/// Sorted, de-duplicated widget types joined by ',' ('consistency,streak'),
/// or 'none'. At most 31 chars, inside GA4's 36-char user property limit.
@visibleForTesting
String homeWidgetsPropertyValue(List<HomeWidgetInfo> widgets) {
  final types = widgets.map(_widgetType).toSet().toList()..sort();
  return types.isEmpty ? 'none' : types.join(',');
}

/// Maps the iOS widget kind / Android receiver class to the same names the
/// widgets' tap deep links use (`widget=` param on home_widget_tapped).
String _widgetType(HomeWidgetInfo info) {
  final id = info.iOSKind ?? info.androidClassName ?? '';
  // iOS Lock Screen widget (streak or consistency, following the app setting).
  if (id == 'PracticeWidget') return 'lock';
  if (id.contains('UpNext')) return 'up_next';
  if (id.contains('Consistency')) return 'consistency';
  // iOS StreakWidget; Android's streak widget is MeditationWidgetReceiver.
  if (id.contains('Streak') || id.contains('MeditationWidget')) {
    return 'streak';
  }
  return 'other';
}
