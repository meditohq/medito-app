import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/constants/widget_constants.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/utils/format_utils.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// This file is the ONLY place where widget data for the home screen widget is written.
// All updates to the Android/iOS home screen widgets must go through the updateWidgets function below.
// Do not write widget data or trigger widget updates from any other file.

/// Updates home screen widgets with meditation stats and subscription status
Future<bool> updateWidgets(LocalAllStats stats) async {
  try {
    await HomeWidget.setAppGroupId(WidgetConstants.widgetGroupId);
    AppLogger.d('WIDGET', 'Updating widget data with stats: ${stats.toJson()}');

    var okCurrent =
        await HomeWidget.saveWidgetData('current_streak', stats.streakCurrent);
    AppLogger.d('WIDGET', 'Saved current_streak: $okCurrent');

    var okBest =
        await HomeWidget.saveWidgetData('best_streak', stats.streakLongest);
    AppLogger.d('WIDGET', 'Saved best_streak: $okBest');

    var okTotalTime =
        await HomeWidget.saveWidgetData('total_time', stats.totalTimeListened);
    AppLogger.d('WIDGET', 'Saved total_time: $okTotalTime');

    var okTotalSessions = await HomeWidget.saveWidgetData(
        'total_sessions', stats.totalTracksCompleted);
    AppLogger.d('WIDGET', 'Saved total_sessions: $okTotalSessions');

    var okConsistencyScore = await HomeWidget.saveWidgetData(
        'consistency_score', stats.consistencyScore);
    AppLogger.d('WIDGET', 'Saved consistency_score: $okConsistencyScore');

    // Save subscription status from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    const subscriptionKey = 'has_active_subscription';
    final hasActiveSubscription = prefs.getBool(subscriptionKey) ?? false;
    AppLogger.d('WIDGET',
        'Saving has_active_subscription to HomeWidget prefs: $hasActiveSubscription');
    var okSubscription = await HomeWidget.saveWidgetData(
      subscriptionKey,
      hasActiveSubscription,
    );
    AppLogger.d('WIDGET', 'Saved has_active_subscription: $okSubscription');

    // Calculate last 7 days' meditation completion
    var nowDate = DateTime.now();
    var last7Days = List.generate(
        7,
        (i) => DateTime(nowDate.year, nowDate.month, nowDate.day)
            .subtract(Duration(days: 6 - i)));
    var completedTimestamps = stats.audioCompleted
            ?.map((e) => DateTime.fromMillisecondsSinceEpoch(e.timestamp))
            .toList() ??
        [];
    var streak7days = last7Days.map((day) {
      return completedTimestamps.any((completed) =>
          completed.year == day.year &&
          completed.month == day.month &&
          completed.day == day.day);
    }).toList();
    var streak7daysJson = jsonEncode(streak7days);
    var okStreak7days = await HomeWidget.saveWidgetData(
        'calendar_streak_7days', streak7daysJson);
    AppLogger.d('WIDGET', 'Saved calendar_streak_7days: $okStreak7days');

    var now = DateTime.now();
    var formattedTime = DateFormat('dd MMM yyyy, HH:mm').format(now);

    var okLastUpdated =
        await HomeWidget.saveWidgetData('last_updated_time', formattedTime);
    AppLogger.d('WIDGET', 'Saved last_updated_time: $okLastUpdated');

    await HomeWidget.updateWidget(
      name: 'StatsWidgetProvider',
      iOSName: 'MeditoStatsWidget',
      qualifiedAndroidName: 'meditofoundation.medito.StatsWidgetReceiver',
    );

    AppLogger.d('WIDGET', 'Android Glance widget updated');

    await _updateIOSWidgets();

    return true;
  } catch (e) {
    AppLogger.e('WIDGET', 'Error updating widget: $e');
    return false;
  }
}

Future<void> _updateIOSWidgets() async {
  try {
    // The primary stats widget
    await HomeWidget.updateWidget(
      iOSName: 'MeditoStatsWidget',
    );

    await HomeWidget.updateWidget(
      name: WidgetConstants.streakWidgetSmallKind,
      iOSName: WidgetConstants.streakWidgetSmallKind,
    );

    await HomeWidget.updateWidget(
      name: WidgetConstants.streakWidgetMediumKind,
      iOSName: WidgetConstants.streakWidgetMediumKind,
    );

    await HomeWidget.updateWidget(
      name: WidgetConstants.quoteWidgetSmallKind,
      iOSName: WidgetConstants.quoteWidgetSmallKind,
    );

    AppLogger.d('WIDGET', 'Widget data updated successfully');
  } catch (e) {
    AppLogger.e('WIDGET', 'Error updating iOS widgets: $e');
  }
}
