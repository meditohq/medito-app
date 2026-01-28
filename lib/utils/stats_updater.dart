import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/types/type_constants.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../providers/notification/reminder_provider.dart';
import '../services/reminders/smart_reminders_service.dart';
import '../providers/feature_flags_provider.dart';
import '../providers/stats_provider.dart';
import '../providers/home/up_next_provider.dart';
import '../providers/settings/settings_providers.dart';
import '../routes/routes.dart';
import '../widgets/snackbar_widget.dart';
import '../l10n/app_localizations.dart';
import 'completed_tracks_storage.dart';
import 'health_kit_manager.dart';
import 'stats_manager.dart';
import '../models/local_audio_completed.dart';
import 'logger.dart';
import '../services/home_widget_service.dart';

// Export the key for backward compatibility if needed
const String completedTracksKey = CompletedTracksStorage.completedTracksKey;

// Static flag to prevent concurrent processing
bool _isProcessingPendingTracks = false;

/// Refreshes the stats provider and invalidates the upNextProvider
/// This ensures the UI shows updated stats immediately after a session is completed
Future<void> _refreshStatsAndUpNext() async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    AppLogger.w('STATS', 'No navigator context available, skipping provider refresh');
    return;
  }

  try {
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(statsProvider.notifier).refreshFromLocal();
      AppLogger.d('STATS', 'Stats provider refreshed from local');
    } catch (refreshError) {
      AppLogger.e('STATS', 'Failed to refresh stats provider', refreshError);
    }

    try {
      container.invalidate(upNextProvider);
      AppLogger.d('STATS', 'UpNext provider invalidated');
    } catch (invalidateError) {
      AppLogger.e('STATS', 'Failed to invalidate upNext provider', invalidateError);
    }
  } catch (_) {
    AppLogger.w('STATS', 'No ProviderScope available, skipping provider refresh');
  }
}

Future<bool> handleStats(
  Map<String, dynamic> payload, {
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
    bool isStreakFreezeEnabled = false;
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final container = ProviderScope.containerOf(context);
        final featureFlags = container.read(featureFlagsProvider);
        isStreakFreezeEnabled = featureFlags.isStreakFreezeEnabled;
      } catch (_) {
        // Fallback: read directly from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        isStreakFreezeEnabled = prefs.getBool('streak_freeze_enabled') ?? false;
      }
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

    // Refresh the stats provider and invalidate upNextProvider
    await _refreshStatsAndUpNext();

    // Update home widget with latest stats (fire-and-forget to avoid blocking)
    try {
      final updatedStats = await statsManager.localAllStats;
      HomeWidgetService.updateWidgetFromStats(updatedStats).catchError((e) {
        AppLogger.e('STATS', 'Failed to update home widget', e);
      });
      AppLogger.d('STATS', 'Home widget update initiated');
    } catch (widgetError) {
      // Don't fail the whole operation if widget update fails
      AppLogger.e(
          'STATS', 'Failed to get stats for widget update', widgetError);
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

        final scheduler = SmartRemindersScheduler(
          prefs: prefs,
          reminders: ReminderProvider(),
        );
        final context = navigatorKey.currentContext;
        await scheduler.rescheduleAfterSession(
          endMs: endMs,
          durationMs: durationMs,
          l10n: context != null ? AppLocalizations.of(context) : null,
        );
        AppLogger.d('STATS', 'Smart Reminder series scheduled');
        
        // Update the reminder time provider state to reflect the new time saved to SharedPreferences
        if (context != null) {
          try {
            final container = ProviderScope.containerOf(context);
            container.read(reminderTimeProvider.notifier).refreshFromPrefs();
          } catch (e) {
            AppLogger.w('STATS', 'Failed to refresh reminder time provider: $e');
          }
        }
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
              'Awarded streak freeze for reaching $currentStreak-day milestone');

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

/// Saves a consistency score entry to historical data
/// Each entry contains the score and datetime timestamp
Future<void> saveConsistencyScoreHistory(
  double consistencyScore,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(
      SharedPreferenceConstants.consistencyScoreHistory,
    );

    List<Map<String, dynamic>> historyList = [];
    if (historyJson != null && historyJson.isNotEmpty) {
      final decoded = jsonDecode(historyJson) as List<dynamic>;
      historyList =
          decoded.map((item) => item as Map<String, dynamic>).toList();
    }

    final entry = {
      'score': consistencyScore,
      'datetime': DateTime.now().millisecondsSinceEpoch,
    };

    historyList.add(entry);

    await prefs.setString(
      SharedPreferenceConstants.consistencyScoreHistory,
      jsonEncode(historyList),
    );

    AppLogger.d('STATS',
        'Saved consistency score history entry: $consistencyScore at ${DateTime.now()}');
  } catch (e) {
    AppLogger.e('STATS', 'Failed to save consistency score history', e);
  }
}

/// Retrieves historical consistency score data
/// Returns a list of maps with 'score' and 'datetime' keys
Future<List<Map<String, dynamic>>> getConsistencyScoreHistory() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(
      SharedPreferenceConstants.consistencyScoreHistory,
    );

    if (historyJson == null || historyJson.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(historyJson) as List<dynamic>;
    return decoded.map((item) => item as Map<String, dynamic>).toList();
  } catch (e) {
    AppLogger.e('STATS', 'Failed to get consistency score history', e);
    return [];
  }
}

/// Checks if a session was manually added (not from a track)
bool isManualSession(LocalAudioCompleted session) {
  return session.id == TypeConstants.manual1 ||
      session.id == TypeConstants.manual2 ||
      session.id == TypeConstants.manual3 ||
      session.id == TypeConstants.manual4;
}

/// Gets the display title for a manual session based on its ID
String getManualSessionTitle(String id, AppLocalizations l10n) {
  switch (id) {
    case TypeConstants.manual1:
      return l10n.morningMeditation;
    case TypeConstants.manual2:
      return l10n.afternoonMeditation;
    case TypeConstants.manual3:
      return l10n.eveningMeditation;
    case TypeConstants.manual4:
      return l10n.nightMeditation;
    default:
      return l10n.manuallyAddedSession;
  }
}

/// Gets the manual session ID based on the time of day
String _getManualSessionId(DateTime dateTime) {
  final hour = dateTime.hour;
  if (hour >= 5 && hour < 12) {
    return TypeConstants.manual1; // Morning
  } else if (hour >= 12 && hour < 18) {
    return TypeConstants.manual2; // Afternoon
  } else if (hour >= 18 && hour < 23) {
    return TypeConstants.manual3; // Evening
  } else {
    return TypeConstants.manual4; // Night
  }
}

/// Skips HealthKit sync as manual sessions shouldn't sync to HealthKit
Future<bool> addManualSession({
  required DateTime dateTime,
  required int durationMinutes,
  StatsManager? statsManager,
}) async {
  try {
    // Validate inputs
    if (dateTime.isAfter(DateTime.now())) {
      AppLogger.e('STATS', 'Cannot add session in the future');
      return false;
    }

    // Allow 0 duration (empty field defaults to 0)
    // Convert duration from minutes to milliseconds
    final durationMs = durationMinutes * 60 * 1000;
    final timestamp = dateTime.millisecondsSinceEpoch;

    // Get the appropriate manual session ID based on time of day
    final manualId = _getManualSessionId(dateTime);

    // Create manual session entry
    final manualSession = LocalAudioCompleted(
      id: manualId,
      timestamp: timestamp,
    );

    // Initialize stats manager if not provided
    statsManager ??= StatsManager()..initialize();

    // Get stats before update for comparison
    final statsBefore = await statsManager.localAllStats;
    final previousStreak = statsBefore.streakCurrent;

    // Add the manual session (this will update streaks, consistency score, etc.)
    await statsManager.addAudioCompleted(manualSession, durationMs);
    AppLogger.d('STATS',
        'Manual session added successfully for ${dateTime.toString()}');

    // Check if user earned a new streak freeze
    bool isStreakFreezeEnabled = false;
    final context = navigatorKey.currentContext;
    if (context != null) {
      try {
        final container = ProviderScope.containerOf(context);
        final featureFlags = container.read(featureFlagsProvider);
        isStreakFreezeEnabled = featureFlags.isStreakFreezeEnabled;
      } catch (_) {
        // Fallback: read directly from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        isStreakFreezeEnabled = prefs.getBool('streak_freeze_enabled') ?? false;
      }
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

    // Refresh the stats provider and invalidate upNextProvider
    await _refreshStatsAndUpNext();

    // Update home widget with latest stats (fire-and-forget to avoid blocking)
    try {
      final updatedStats = await statsManager.localAllStats;
      HomeWidgetService.updateWidgetFromStats(updatedStats).catchError((e) {
        AppLogger.e('STATS', 'Failed to update home widget', e);
      });
      AppLogger.d('STATS', 'Home widget update initiated');
    } catch (widgetError) {
      // Don't fail the whole operation if widget update fails
      AppLogger.e(
          'STATS', 'Failed to get stats for widget update', widgetError);
    }

    return true;
  } catch (e) {
    AppLogger.e('STATS', 'Failed to add manual session', e);
    return false;
  }
}
