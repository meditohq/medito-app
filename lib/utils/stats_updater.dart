import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/types/type_constants.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../providers/notification/reminder_provider.dart';
import '../services/reminders/smart_reminders_service.dart';
import '../providers/feature_flags_provider.dart';
import '../routes/routes.dart';
import '../widgets/snackbar_widget.dart';
import '../l10n/app_localizations.dart';
import 'completed_tracks_storage.dart';
import 'health_kit_manager.dart';
import 'stats_manager.dart';
import '../models/local_audio_completed.dart';
import 'logger.dart';
import 'widget_updater.dart';

// Export the key for backward compatibility if needed
const String completedTracksKey = CompletedTracksStorage.completedTracksKey;

// Static flag to prevent concurrent processing
bool _isProcessingPendingTracks = false;

// Widget updates are handled exclusively by widget_updater.dart.
// This file should only call updateWidgets when stats change, and should not contain widget update logic itself.

Future<bool> handleStats(
  Map<String, dynamic> payload, {
  WidgetRef? ref,
  StatsManager? statsManager, // For testing
}) async {
  try {
    // First try to sync with HealthKit
    await _syncHealthKit(payload).catchError((e) {
      AppLogger.e('STATS', 'HealthKit sync error', e);
      // Continue even if HealthKit sync fails
    });

    // Then update local stats
    statsManager ??= StatsManager()..initialize();

    var newAudioCompleted = LocalAudioCompleted(
      id: payload[TypeConstants.trackIdKey],
      timestamp: payload[TypeConstants.timestampIdKey],
    );

    var duration = payload[TypeConstants.durationIdKey];

    // Get stats before update for comparison
    var statsBefore = await statsManager.localAllStats;
    var previousStreak = statsBefore.streakCurrent;

    await statsManager.addAudioCompleted(newAudioCompleted, duration);
    AppLogger.d('STATS',
        'Stats updated successfully for track ${newAudioCompleted.id}');

    // Check if user earned a new streak freeze
    bool isStreakFreezeEnabled;
    if (ref != null) {
      final featureFlags = ref.read(featureFlagsProvider);
      isStreakFreezeEnabled = featureFlags.isStreakFreezeEnabled;
    } else {
      // Fallback: read directly from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      isStreakFreezeEnabled = prefs.getBool('streak_freeze_enabled') ?? false;
    }

    await _checkAndAwardStreakFreeze(
      statsManager: statsManager,
      previousStreak: previousStreak,
      isStreakFreezeEnabled: isStreakFreezeEnabled,
    );

    // Update widgets with new stats data
    try {
      var allStats = await statsManager.localAllStats;
      await updateWidgets(allStats);
      AppLogger.d('STATS', 'Widgets updated with latest stats');
    } catch (widgetError) {
      // Don't fail the whole operation if widget update fails
      AppLogger.e('STATS', 'Failed to update widgets', widgetError);
    }

    // Schedule or reschedule Smart Reminders based on latest session time
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSaved =
          prefs.getInt(SharedPreferenceConstants.savedHours) != null &&
              prefs.getInt(SharedPreferenceConstants.savedMinutes) != null;
      final enabled =
          prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled) ??
              hasSaved;

      if (enabled) {
        final endMs = payload[TypeConstants.timestampIdKey] as int;
        final durationMs = payload[TypeConstants.durationIdKey] as int;

        final currentStats = await statsManager.localAllStats;
        final streak = currentStats.streakCurrent;
        final consistency = currentStats.consistencyScore;

        final scheduler = SmartRemindersScheduler(
          prefs: prefs,
          reminders: ReminderProvider(),
        );
        await scheduler.rescheduleAfterSession(
          endMs: endMs,
          durationMs: durationMs,
          streak: streak,
          consistency: consistency,
        );
        AppLogger.d('STATS', 'Smart Reminder series scheduled');
      } else {
        AppLogger.d('STATS', 'Smart Reminders disabled; skipping scheduling');
      }
    } catch (reminderError) {
      AppLogger.e('STATS', 'Failed to schedule Smart Reminder', reminderError);
    }

    return true;
  } catch (e) {
    AppLogger.e('STATS', 'Failed to update stats', e);
    return false;
  }
}

/// Process any pending track completions that were stored while the app was in the background.
/// This is typically called when the app starts or returns to the foreground.
///
/// Returns the number of successfully processed tracks.
///
/// Example:
/// ```dart
/// processPendingCompletedTracks().then((count) {
///   if (count > 0) print('Processed $count tracks');
/// });
/// ```
Future<int> processPendingCompletedTracks([SharedPreferences? prefs]) async {
  // If already processing, skip this call
  if (_isProcessingPendingTracks) {
    AppLogger.d(
        'STATS', 'Already processing pending tracks, skipping this call');
    return 0;
  }

  try {
    _isProcessingPendingTracks = true;

    // Use the provided SharedPreferences or create a new storage
    final storage = prefs != null
        ? CompletedTracksStorage(prefs)
        : await CompletedTracksStorage.create();

    final pendingTracksJson = storage.getPendingTracks();
    if (pendingTracksJson.isEmpty) {
      _isProcessingPendingTracks = false;
      return 0;
    }

    int successCount = 0;
    List<String> failedTracks = [];

    // Process each pending track
    for (var trackJson in pendingTracksJson) {
      try {
        final payload = Map<String, dynamic>.from(
            jsonDecode(trackJson) as Map<dynamic, dynamic>);

        final success = await handleStats(payload);
        if (success) {
          successCount++;
        } else {
          failedTracks.add(trackJson);
        }
      } catch (e) {
        failedTracks.add(trackJson);
        AppLogger.e('STATS', 'Error processing track', e);
      }
    }

    // Update storage with the tracks that failed to process
    await storage.updatePendingTracks(failedTracks);

    // If any tracks were processed successfully, update the widgets
    if (successCount > 0) {
      try {
        var statsManager = StatsManager()..initialize();
        var allStats = await statsManager.localAllStats;
        await updateWidgets(allStats);
        AppLogger.d('STATS',
            'Widgets updated after processing $successCount pending tracks');
      } catch (widgetError) {
        AppLogger.e(
            'STATS',
            'Failed to update widgets after processing pending tracks',
            widgetError);
      }
    }

    return successCount;
  } catch (e) {
    AppLogger.e('STATS', 'Error processing pending tracks', e);
    return 0;
  } finally {
    _isProcessingPendingTracks = false;
  }
}

/// Store a track completion payload for later processing.
/// This is typically called when immediate stats processing fails.
Future<void> storeTrackCompletion(
    SharedPreferences prefs, Map<String, dynamic> payload) async {
  final storage = CompletedTracksStorage(prefs);
  await storage.addCompletedTrack(payload);

  // Even though we couldn't process the stats now,
  // try to update the widgets with current stats
  try {
    var statsManager = StatsManager()..initialize();
    var allStats = await statsManager.localAllStats;
    await updateWidgets(allStats);
    AppLogger.d('STATS',
        'Widgets updated with current stats after storing track for later processing');
  } catch (widgetError) {
    // Don't fail if widget update fails
    AppLogger.e(
        'STATS', 'Failed to update widgets after storing track', widgetError);
  }
}

Future<void> _syncHealthKit(Map<String, dynamic> payload) async {
  var healthKitManager = HealthKitManager();

  if (!await healthKitManager
      .isSessionSynced(payload[TypeConstants.timestampIdKey])) {
    var success = await _updateHealthKit(payload);
    if (success) {
      await healthKitManager
          .markSessionAsSynced(payload[TypeConstants.timestampIdKey]);
    }
  }
}

Future<bool> _updateHealthKit(Map<String, dynamic> payload) async {
  final end = DateTime.fromMillisecondsSinceEpoch(
    payload[TypeConstants.timestampIdKey],
  );
  final start = end
      .subtract(Duration(milliseconds: payload[TypeConstants.durationIdKey]));

  return await HealthKitManager().writeMindfulnessData(start, end);
}

const int _streakFreezeInterval = 3;

Future<void> _checkAndAwardStreakFreeze({
  required StatsManager statsManager,
  required int previousStreak,
  required bool isStreakFreezeEnabled,
}) async {
  try {
    AppLogger.d('STREAK_FREEZE', '=== Starting streak freeze check ===');
    AppLogger.d('STREAK_FREEZE', 'Previous streak: $previousStreak');
    AppLogger.d('STREAK_FREEZE', 'Feature enabled: $isStreakFreezeEnabled');

    if (!isStreakFreezeEnabled) {
      AppLogger.d('STREAK_FREEZE', 'Feature disabled, returning early');
      return;
    }

    var currentStats = await statsManager.localAllStats;
    var currentStreak = currentStats.streakCurrent;
    AppLogger.d('STREAK_FREEZE', 'Current streak: $currentStreak');

    final previousMilestone = (previousStreak / _streakFreezeInterval).floor();
    final currentMilestone = (currentStreak / _streakFreezeInterval).floor();
    AppLogger.d('STREAK_FREEZE',
        'Previous milestone: $previousMilestone, Current milestone: $currentMilestone');
    AppLogger.d('STREAK_FREEZE',
        'Streak % $_streakFreezeInterval = ${currentStreak % _streakFreezeInterval}');
    if (currentStreak > 0 &&
        currentMilestone > previousMilestone &&
        currentStreak % _streakFreezeInterval == 0) {
      AppLogger.d('STREAK_FREEZE', 'Milestone conditions met!');

      // Check if user hasn't already reached max streak freezes
      final currentFreezes = currentStats.streakFreezes ?? 0;
      final maxFreezes = currentStats.maxStreakFreezes ?? 0;
      AppLogger.d('STREAK_FREEZE',
          'Current freezes: $currentFreezes, Max freezes: $maxFreezes');

      if (currentFreezes < maxFreezes) {
        AppLogger.d('STREAK_FREEZE', 'Under max freezes limit');

        // Check if we've already awarded a freeze today (max 1 per day)
        final hasAwardedToday = await _hasAwardedFreezeToday();
        AppLogger.d('STREAK_FREEZE', 'Already awarded today: $hasAwardedToday');

        if (!hasAwardedToday) {
          AppLogger.d('STREAK_FREEZE', 'AWARDING STREAK FREEZE!');

          // Award one new streak freeze
          await statsManager.awardStreakFreeze();

          // Mark that we've awarded a freeze today
          await _markFreezeAwardedToday();

          AppLogger.d('STREAK_FREEZE',
              'Awarded streak freeze for reaching ${currentStreak}-day milestone');

          // Show snackbar notification
          final context = navigatorKey.currentContext;
          AppLogger.d('STREAK_FREEZE',
              'Navigator context available: ${context != null}');
          if (context != null) {
            AppLogger.d('STREAK_FREEZE', 'Showing snackbar...');
            showSnackBar(
                context, AppLocalizations.of(context)!.streakFreezeEarned);
          } else {
            AppLogger.w('STREAK_FREEZE', 'No context available for snackbar');
          }
        } else {
          AppLogger.d('STREAK_FREEZE',
              'Skipped awarding freeze - already awarded one today');
        }
      } else {
        AppLogger.d('STREAK_FREEZE', 'Already at max freezes');
      }
    } else {
      AppLogger.d('STREAK_FREEZE', 'Milestone conditions NOT met');
      AppLogger.d('STREAK_FREEZE', 'currentStreak > 0: ${currentStreak > 0}');
      AppLogger.d('STREAK_FREEZE',
          'currentMilestone > previousMilestone: ${currentMilestone > previousMilestone}');
      AppLogger.d(
          'STREAK_FREEZE', 'currentStreak % 7 == 0: ${currentStreak % 7 == 0}');
    }
  } catch (e) {
    AppLogger.e('STREAK_FREEZE', 'Error checking for streak freeze award', e);
  }
}

/// Checks if a streak freeze has already been awarded today
Future<bool> _hasAwardedFreezeToday() async {
  final prefs = await SharedPreferences.getInstance();
  final lastAwardDate = prefs.getString('last_streak_freeze_award_date');
  final today =
      DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD format

  return lastAwardDate == today;
}

/// Marks that a streak freeze has been awarded today
Future<void> _markFreezeAwardedToday() async {
  final prefs = await SharedPreferences.getInstance();
  final today =
      DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD format
  await prefs.setString('last_streak_freeze_award_date', today);
}
