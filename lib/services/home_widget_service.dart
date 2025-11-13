import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

class HomeWidgetService {
  static const String _widgetName = 'MeditationWidgetReceiver';
  static const String _consistencyWidgetName = 'ConsistencyWidgetReceiver';
  static const String _streakCurrentKey = 'streak_current';
  static const String _meditationDatesKey = 'meditation_dates';
  static const String _freezeDatesKey = 'freeze_dates';
  static const String _dayLabelKey = 'day_label';
  static const String _daysLabelKey = 'days_label';
  static const String _lastUpdatedKey = 'last_updated';
  static const String _totalTracksCompletedKey = 'total_tracks_completed';
  static const String _consistencyScoreKey = 'consistency_score';
  static const String _themePreferenceKey = 'theme_preference';

  /// Saves the theme preference to the widget
  static Future<void> saveThemePreference(String themePreference) async {
    try {
      await HomeWidget.saveWidgetData<String>(
        _themePreferenceKey,
        themePreference,
      );
      AppLogger.d('WIDGET', 'Saved theme preference: $themePreference');

      // Update both widgets when theme changes (Android only)
      if (Platform.isAndroid) {
        await _updateWidget(_widgetName);
        await _updateWidget(_consistencyWidgetName);
      }
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to save theme preference', e);
    }
  }

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

      // Save consistency score as integer percentage (0-100) to avoid type conversion issues
      final consistencyPercentage =
          (stats.consistencyScore * 100).round().clamp(0, 100);
      await HomeWidget.saveWidgetData<int>(
        _consistencyScoreKey,
        consistencyPercentage,
      );

      // Update both widgets - try home_widget package first, fallback to manual broadcast (Android only)
      if (Platform.isAndroid) {
        await _updateWidget(_widgetName);
        await _updateWidget(_consistencyWidgetName);
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

      // Save data to widget (using default labels) with timeout to prevent ANR
      try {
        await HomeWidget.saveWidgetData<int>(
          _streakCurrentKey,
          stats.streakCurrent,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for streak_current: $e');
      }

      try {
        await HomeWidget.saveWidgetData<String>(
          _meditationDatesKey,
          jsonEncode(uniqueMeditationDates),
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for meditation_dates: $e');
      }

      try {
        await HomeWidget.saveWidgetData<String>(
          _freezeDatesKey,
          jsonEncode(freezeDates),
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for freeze_dates: $e');
      }

      try {
        await HomeWidget.saveWidgetData<String>(
          _dayLabelKey,
          'day',
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w('WIDGET', 'saveWidgetData timeout/error for day_label: $e');
      }

      try {
        await HomeWidget.saveWidgetData<String>(
          _daysLabelKey,
          'days',
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for days_label: $e');
      }

      try {
        await HomeWidget.saveWidgetData<int>(
          _lastUpdatedKey,
          DateTime.now().millisecondsSinceEpoch,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for last_updated: $e');
      }

      try {
        await HomeWidget.saveWidgetData<int>(
          _totalTracksCompletedKey,
          stats.totalTracksCompleted,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w('WIDGET',
            'saveWidgetData timeout/error for total_tracks_completed: $e');
      }

      // Save consistency score as integer percentage (0-100) to avoid type conversion issues
      final consistencyPercentage =
          (stats.consistencyScore * 100).round().clamp(0, 100);
      try {
        await HomeWidget.saveWidgetData<int>(
          _consistencyScoreKey,
          consistencyPercentage,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        AppLogger.w(
            'WIDGET', 'saveWidgetData timeout/error for consistency_score: $e');
      }
      // Update both widgets - try home_widget package first, fallback to manual broadcast (Android only)
      if (Platform.isAndroid) {
        await _updateWidget(_widgetName);
        await _updateWidget(_consistencyWidgetName);
      }
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update widget (fromStats)', e);
    }
  }

  /// Updates widgets using manual broadcast
  /// Android only - iOS widgets update automatically via App Groups
  static Future<void> _updateWidget(String widgetName) async {
    if (!Platform.isAndroid) {
      return;
    }

    await _sendWidgetUpdateBroadcast();
  }

  /// Manually sends a broadcast to trigger widget update for Glance widgets
  /// Android only
  static Future<void> _sendWidgetUpdateBroadcast() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      const platform = MethodChannel('medito.app/widget');
      await platform.invokeMethod('updateWidget').timeout(
            const Duration(seconds: 2),
          );
      AppLogger.d('WIDGET', 'Manual widget update broadcast sent');
    } on TimeoutException {
      AppLogger.w('WIDGET', 'Widget update broadcast timeout');
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to send manual widget update broadcast', e);
    }
  }

  /// Requests to pin a widget to the home screen (Android only)
  /// widgetType: "meditation" or "consistency"
  static Future<bool> pinWidget({String widgetType = 'consistency'}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      const platform = MethodChannel('medito.app/widget');
      final result = await platform.invokeMethod<bool>(
        'pinWidget',
        {'widgetType': widgetType},
      );
      AppLogger.d('WIDGET', 'Widget pin request sent for type: $widgetType');
      return result ?? false;
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to pin widget', e);
      return false;
    }
  }
}
