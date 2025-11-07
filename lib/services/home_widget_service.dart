import 'dart:convert';

import 'package:home_widget/home_widget.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class HomeWidgetService {
  static const String _widgetName = 'MeditationWidgetReceiver';
  static const String _streakCurrentKey = 'streak_current';
  static const String _meditationDatesKey = 'meditation_dates';
  static const String _freezeDatesKey = 'freeze_dates';
  static const String _dayLabelKey = 'day_label';
  static const String _daysLabelKey = 'days_label';
  static const String _lastUpdatedKey = 'last_updated';
  static const String _totalTracksCompletedKey = 'total_tracks_completed';

  /// Updates the home widget with the latest stats data
  static Future<void> updateWidget({
    required LocalAllStats stats,
    BuildContext? context,
  }) async {
    try {
      // Extract meditation dates from audioCompleted
      final meditationDates = <int>[];
      if (stats.audioCompleted != null) {
        for (final audio in stats.audioCompleted!) {
          final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          final dayStart = DateTime(date.year, date.month, date.day);
          meditationDates.add(dayStart.millisecondsSinceEpoch);
        }
      }

      // Remove duplicates
      final uniqueMeditationDates = meditationDates.toSet().toList();

      // Extract freeze usage dates
      final freezeDates = stats.freezeUsageDates.toList();

      // Get localized "day" and "days" labels
      String dayLabel = 'day';
      String daysLabel = 'days';
      if (context != null) {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          dayLabel = l10n.day;
          daysLabel = l10n.days;
        }
      }

      // Save data to widget
      await HomeWidget.saveWidgetData<int>(
        _streakCurrentKey,
        stats.streakCurrent,
      );

      await HomeWidget.saveWidgetData<String>(
        _meditationDatesKey,
        jsonEncode(uniqueMeditationDates),
      );

      await HomeWidget.saveWidgetData<String>(
        _freezeDatesKey,
        jsonEncode(freezeDates),
      );

      await HomeWidget.saveWidgetData<String>(
        _dayLabelKey,
        dayLabel,
      );

      await HomeWidget.saveWidgetData<String>(
        _daysLabelKey,
        daysLabel,
      );

      await HomeWidget.saveWidgetData<int>(
        _lastUpdatedKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      await HomeWidget.saveWidgetData<int>(
        _totalTracksCompletedKey,
        stats.totalTracksCompleted,
      );

      AppLogger.d('WIDGET', 'Saved widget data - streak: ${stats.streakCurrent}, sessions: ${stats.totalTracksCompleted}');

      // Update the widget - try home_widget package first, fallback to manual broadcast
      AppLogger.d('WIDGET', 'Calling HomeWidget.updateWidget() with name: $_widgetName');
      try {
        await HomeWidget.updateWidget(
          name: _widgetName,
          androidName: _widgetName,
        );
        AppLogger.d('WIDGET', 'HomeWidget.updateWidget() completed');
      } catch (e) {
        AppLogger.w('WIDGET', 'HomeWidget.updateWidget() failed, sending manual broadcast: $e');
        // Manually send broadcast for Glance widget
        await _sendWidgetUpdateBroadcast();
      }
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update widget', e);
    }
  }

  /// Updates the widget using stats from a provider/notifier
  /// This version doesn't require a BuildContext for localization
  static Future<void> updateWidgetFromStats(LocalAllStats stats) async {
    try {
      // Extract meditation dates from audioCompleted
      final meditationDates = <int>[];
      if (stats.audioCompleted != null) {
        for (final audio in stats.audioCompleted!) {
          final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
          final dayStart = DateTime(date.year, date.month, date.day);
          meditationDates.add(dayStart.millisecondsSinceEpoch);
        }
      }

      // Remove duplicates
      final uniqueMeditationDates = meditationDates.toSet().toList();

      // Extract freeze usage dates
      final freezeDates = stats.freezeUsageDates.toList();

      // Save data to widget (using default labels)
      await HomeWidget.saveWidgetData<int>(
        _streakCurrentKey,
        stats.streakCurrent,
      );

      await HomeWidget.saveWidgetData<String>(
        _meditationDatesKey,
        jsonEncode(uniqueMeditationDates),
      );

      await HomeWidget.saveWidgetData<String>(
        _freezeDatesKey,
        jsonEncode(freezeDates),
      );

      await HomeWidget.saveWidgetData<String>(
        _dayLabelKey,
        'day',
      );

      await HomeWidget.saveWidgetData<String>(
        _daysLabelKey,
        'days',
      );

      await HomeWidget.saveWidgetData<int>(
        _lastUpdatedKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      await HomeWidget.saveWidgetData<int>(
        _totalTracksCompletedKey,
        stats.totalTracksCompleted,
      );

      AppLogger.d('WIDGET', 'Saved widget data (fromStats) - streak: ${stats.streakCurrent}, sessions: ${stats.totalTracksCompleted}');

      // Update the widget - try home_widget package first, fallback to manual broadcast
      AppLogger.d('WIDGET', 'Calling HomeWidget.updateWidget() (fromStats) with name: $_widgetName');
      try {
        await HomeWidget.updateWidget(
          name: _widgetName,
          androidName: _widgetName,
        );
        AppLogger.d('WIDGET', 'HomeWidget.updateWidget() (fromStats) completed');
      } catch (e) {
        AppLogger.w('WIDGET', 'HomeWidget.updateWidget() (fromStats) failed, sending manual broadcast: $e');
        // Manually send broadcast for Glance widget
        await _sendWidgetUpdateBroadcast();
      }
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update widget (fromStats)', e);
    }
  }

  /// Manually sends a broadcast to trigger widget update for Glance widgets
  static Future<void> _sendWidgetUpdateBroadcast() async {
    try {
      const platform = MethodChannel('medito.app/widget');
      await platform.invokeMethod('updateWidget');
      AppLogger.d('WIDGET', 'Manual widget update broadcast sent');
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to send manual widget update broadcast', e);
    }
  }
}

