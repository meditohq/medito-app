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
  static const String _appGroupId = 'group.org.medito.widget';
  static const String _widgetName = 'MeditationWidgetReceiver';
  static const String _consistencyWidgetName = 'ConsistencyWidgetReceiver';

  // Coalesces rapid back-to-back broadcast requests into a single platform
  // round trip. Multiple sources (stats refresh, up-next change, theme change)
  // can update SharedPreferences within the same frame.
  static Timer? _broadcastDebounce;
  static const Duration _broadcastCoalesceWindow = Duration(milliseconds: 100);
  static const String _streakCurrentKey = 'streak_current';
  static const String _meditationDatesKey = 'meditation_dates';
  static const String _freezeDatesKey = 'freeze_dates';
  static const String _dayLabelKey = 'day_label';
  static const String _daysLabelKey = 'days_label';
  static const String _lastUpdatedKey = 'last_updated';
  static const String _totalTracksCompletedKey = 'total_tracks_completed';
  static const String _consistencyScoreKey = 'consistency_score';
  static const String _themePreferenceKey = 'theme_preference';
  static const String _upNextTitleKey = 'up_next_title';
  static const String _upNextSubtitleKey = 'up_next_subtitle';
  static const String _upNextPackTitleKey = 'up_next_pack_title';
  static const String _upNextCompletedKey = 'up_next_completed';
  static const String _upNextTotalKey = 'up_next_total';
  static const String _upNextTrackIdKey = 'up_next_track_id';

  static Future<void> _configure() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(_appGroupId);
    }
  }

  /// Saves the theme preference to the widget
  static Future<void> saveThemePreference(String themePreference) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        _themePreferenceKey,
        themePreference,
      );
      AppLogger.d('WIDGET', 'Saved theme preference: $themePreference');

      await _updateWidget(_widgetName);
      await _updateWidget(_consistencyWidgetName);
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to save theme preference', e);
    }
  }

  /// Updates the home widget with the latest stats data
  static Future<void> updateWidget({
    required LocalAllStats stats,
    BuildContext? context,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      // Resolve localised strings before any await so we never touch BuildContext
      // across an async gap.
      final l10n = context != null ? AppLocalizations.of(context) : null;
      final dayLabel = l10n?.day ?? 'day';
      final daysLabel = l10n?.days ?? 'days';

      await _configure();

      final meditationDates = _extractMeditationDates(stats);
      final freezeDates = stats.freezeUsageDates.toList();

      final consistencyPercentage = (stats.consistencyScore * 100).round().clamp(0, 100);
      await Future.wait([
        HomeWidget.saveWidgetData<int>(_streakCurrentKey, stats.streakCurrent),
        HomeWidget.saveWidgetData<String>(_meditationDatesKey, jsonEncode(meditationDates)),
        HomeWidget.saveWidgetData<String>(_freezeDatesKey, jsonEncode(freezeDates)),
        HomeWidget.saveWidgetData<String>(_dayLabelKey, dayLabel),
        HomeWidget.saveWidgetData<String>(_daysLabelKey, daysLabel),
        HomeWidget.saveWidgetData<int>(_lastUpdatedKey, DateTime.now().millisecondsSinceEpoch),
        HomeWidget.saveWidgetData<int>(_totalTracksCompletedKey, stats.totalTracksCompleted),
        HomeWidget.saveWidgetData<int>(_consistencyScoreKey, consistencyPercentage),
      ]);

      await _triggerWidgetRefresh();
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update widget', e);
    }
  }

  /// Updates the widget using stats from a provider/notifier (no BuildContext needed)
  static Future<void> updateWidgetFromStats(LocalAllStats stats) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await _configure();

      final meditationDates = _extractMeditationDates(stats);
      final freezeDates = stats.freezeUsageDates.toList();
      final consistencyPercentage = (stats.consistencyScore * 100).round().clamp(0, 100);

      await Future.wait([
        _saveWithTimeout(_streakCurrentKey, stats.streakCurrent),
        _saveWithTimeout(_meditationDatesKey, jsonEncode(meditationDates)),
        _saveWithTimeout(_freezeDatesKey, jsonEncode(freezeDates)),
        _saveWithTimeout(_dayLabelKey, 'day'),
        _saveWithTimeout(_daysLabelKey, 'days'),
        _saveWithTimeout(_lastUpdatedKey, DateTime.now().millisecondsSinceEpoch),
        _saveWithTimeout(_totalTracksCompletedKey, stats.totalTracksCompleted),
        _saveWithTimeout(_consistencyScoreKey, consistencyPercentage),
      ]);

      await _triggerWidgetRefresh();
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update widget (fromStats)', e);
    }
  }

  static List<int> _extractMeditationDates(LocalAllStats stats) {
    final dates = <int>[];
    if (stats.audioCompleted != null) {
      for (final audio in stats.audioCompleted!) {
        final date = DateTime.fromMillisecondsSinceEpoch(audio.timestamp);
        final dayStart = DateTime(date.year, date.month, date.day);
        dates.add(dayStart.millisecondsSinceEpoch);
      }
    }

    return dates.toSet().toList();
  }

  static Future<void> _saveWithTimeout<T>(String key, T value) async {
    try {
      await HomeWidget.saveWidgetData<T>(key, value).timeout(const Duration(seconds: 2));
    } catch (e) {
      AppLogger.w('WIDGET', 'saveWidgetData timeout/error for $key: $e');
    }
  }

  static Future<void> _triggerWidgetRefresh() async {
    if (Platform.isAndroid) {
      await _sendWidgetUpdateBroadcast();
    } else if (Platform.isIOS) {
      await _updateWidgetsIOS();
    }
  }

  static Future<void> _updateWidgetsIOS() async {
    try {
      await HomeWidget.updateWidget(iOSName: 'StreakWidget');
      await HomeWidget.updateWidget(iOSName: 'ConsistencyWidget');
      AppLogger.d('WIDGET', 'iOS widget reload triggered');
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to trigger iOS widget reload', e);
    }
  }

  static Future<void> _updateWidget(String widgetName) async {
    if (!Platform.isAndroid) {
      return;
    }

    await _sendWidgetUpdateBroadcast();
  }

  static Future<void> _sendWidgetUpdateBroadcast() async {
    if (!Platform.isAndroid) {
      return;
    }

    _broadcastDebounce?.cancel();
    _broadcastDebounce = Timer(_broadcastCoalesceWindow, () async {
      try {
        const platform = MethodChannel('medito.app/widget');
        await platform.invokeMethod('updateWidget').timeout(
              const Duration(seconds: 2),
            );
        AppLogger.d('WIDGET', 'Manual widget update broadcast sent');
      } on TimeoutException {
        AppLogger.w('WIDGET', 'Widget update broadcast timeout');
      } catch (e) {
        AppLogger.e(
            'WIDGET', 'Failed to send manual widget update broadcast', e);
      }
    });
  }

  /// Updates the Up Next widget with the current session info
  static Future<void> updateUpNextWidget({
    required String title,
    required String packTitle,
    required String trackId,
    String? subtitle,
    required int completed,
    required int total,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }

    try {
      await _configure();
      await Future.wait([
        HomeWidget.saveWidgetData<String>(_upNextTitleKey, title),
        HomeWidget.saveWidgetData<String>(_upNextPackTitleKey, packTitle),
        HomeWidget.saveWidgetData<String>(_upNextSubtitleKey, subtitle ?? ''),
        HomeWidget.saveWidgetData<String>(_upNextTrackIdKey, trackId),
        HomeWidget.saveWidgetData<int>(_upNextCompletedKey, completed),
        HomeWidget.saveWidgetData<int>(_upNextTotalKey, total),
      ]);

      await _triggerWidgetRefresh();
      if (Platform.isIOS) {
        await HomeWidget.updateWidget(iOSName: 'UpNextWidget');
      }
    } catch (e) {
      AppLogger.e('WIDGET', 'Failed to update up next widget', e);
    }
  }

  /// Requests to pin a widget to the home screen (Android only)
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
