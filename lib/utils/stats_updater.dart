import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/types/type_constants.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../providers/notification/reminder_provider.dart';
import '../services/reminders/smart_reminders_service.dart';
import '../providers/stats_provider.dart';
import '../providers/home/up_next_provider.dart';
import '../providers/settings/settings_providers.dart';
import '../routes/routes.dart';
import '../l10n/app_localizations.dart';
import 'completed_tracks_storage.dart';
import 'health_kit_manager.dart';
import 'stats_manager.dart';
import '../models/local_audio_completed.dart';
import 'logger.dart';
import '../services/home_widget_service.dart';
import '../services/analytics/firebase_analytics_service.dart';
import '../constants/strings/analytics_event_constants.dart';

// Export the key for backward compatibility if needed
const String completedTracksKey = CompletedTracksStorage.completedTracksKey;

/// Local hour-of-day at which manual sessions are anchored. Noon keeps the
/// entry unambiguously inside its calendar day regardless of the user's
/// day-boundary offset. Public so the calendar's streak preview matches.
const int manualSessionAnchorHour = 12;

// Static flag to prevent concurrent processing
bool _isProcessingPendingTracks = false;

/// Refreshes the stats provider and invalidates the upNextProvider
/// This ensures the UI shows updated stats immediately after a session is completed
Future<void> _refreshStatsAndUpNext() async {
  final context = navigatorKey.currentContext;
  if (context == null) {
    AppLogger.w(
        'STATS', 'No navigator context available, skipping provider refresh');
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
      AppLogger.e(
          'STATS', 'Failed to invalidate upNext provider', invalidateError);
    }
  } catch (_) {
    AppLogger.w(
        'STATS', 'No ProviderScope available, skipping provider refresh');
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

    await statsManager.addAudioCompleted(newAudioCompleted, duration);
    AppLogger.d('STATS',
        'Stats updated successfully for track ${newAudioCompleted.id}');

    // Log Firebase analytics event for audio session completion
    try {
      final fileId = payload[TypeConstants.fileIdKey] as String?;
      final guide = payload[TypeConstants.guideIdKey] as String?;

      await FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.audioSessionCompleted,
        parameters: {
          AnalyticsEventConstants.paramAudioFileId: fileId ?? 'unknown',
          AnalyticsEventConstants.paramAudioFileGuide: guide ?? 'unknown',
          AnalyticsEventConstants.paramAudioFileDuration: duration,
        },
      );
      AppLogger.d('STATS', 'Logged audio_session_completed event to Firebase');
    } catch (analyticsError) {
      AppLogger.e('STATS', 'Failed to log analytics event', analyticsError);
    }

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
          l10n: context != null && context.mounted
              ? AppLocalizations.of(context)
              : null,
        );
        AppLogger.d('STATS', 'Smart Reminder series scheduled');

        // Update the reminder time provider state to reflect the new time saved to SharedPreferences
        if (context != null && context.mounted) {
          try {
            final container = ProviderScope.containerOf(context);
            container.read(reminderTimeProvider.notifier).refreshFromPrefs();
          } catch (e) {
            AppLogger.w(
                'STATS', 'Failed to refresh reminder time provider: $e');
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

bool isFreezeSession(LocalAudioCompleted session) {
  return session.id == TypeConstants.streakFreeze;
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

/// Removes a previously recorded session from stats.
///
/// Matches on id + timestamp so that duplicate ids on different days are
/// unaffected. Recalculates streak + consistency, refreshes providers, and
/// updates the home widget.
Future<bool> deleteSession({
  required LocalAudioCompleted session,
  StatsManager? statsManager,
}) async {
  try {
    statsManager ??= StatsManager()..initialize();
    await statsManager.removeAudioCompleted(session);

    await _refreshStatsAndUpNext();

    try {
      final updatedStats = await statsManager.localAllStats;
      HomeWidgetService.updateWidgetFromStats(updatedStats).catchError((e) {
        AppLogger.e('STATS', 'Failed to update home widget', e);
      });
    } catch (widgetError) {
      AppLogger.e(
          'STATS', 'Failed to get stats for widget update', widgetError);
    }

    return true;
  } catch (e) {
    AppLogger.e('STATS', 'Failed to delete session', e);
    return false;
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

    // Add the manual session (this will update streaks, consistency score, etc.)
    await statsManager.addAudioCompleted(manualSession, durationMs);
    AppLogger.d('STATS',
        'Manual session added successfully for ${dateTime.toString()}');

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

/// Adds a manual session to each date in [dates] at noon, with the same
/// [durationMinutes] applied to every day. Stats are recalculated after every
/// insert (StatsManager requires it for streak math), but provider refresh and
/// home-widget update happen once at the end so the UI doesn't thrash.
///
/// Returns the count of dates successfully added. Future-dated entries are
/// silently skipped.
Future<int> addManualSessions({
  required List<DateTime> dates,
  required int durationMinutes,
  StatsManager? statsManager,
}) async {
  statsManager ??= StatsManager()..initialize();
  final durationMs = durationMinutes * 60 * 1000;
  // Read "now" from the manager so test clock injection
  // (setCurrentDateForTesting) flows through here too.
  final now = statsManager.currentDate;
  var added = 0;

  for (final date in dates) {
    // Anchor at the shared manual-session hour so the calendar's streak
    // preview agrees with how this entry will actually be bucketed.
    final dateTime = DateTime(
      date.year,
      date.month,
      date.day,
      manualSessionAnchorHour,
    );
    if (dateTime.isAfter(now)) continue;

    try {
      final manualId = _getManualSessionId(dateTime);
      final entry = LocalAudioCompleted(
        id: manualId,
        timestamp: dateTime.millisecondsSinceEpoch,
      );
      await statsManager.addAudioCompleted(entry, durationMs,
          skipPost: true);
      added++;
    } catch (e) {
      AppLogger.e('STATS', 'Failed to add manual session in bulk for $date', e);
    }
  }

  if (added > 0) {
    // Post the batched result once, instead of once per day.
    try {
      await statsManager.flushPendingPost();
    } catch (e) {
      AppLogger.e('STATS', 'Failed to post batched manual sessions', e);
    }
    await _refreshStatsAndUpNext();
    try {
      final updatedStats = await statsManager.localAllStats;
      HomeWidgetService.updateWidgetFromStats(updatedStats).catchError((e) {
        AppLogger.e('STATS', 'Failed to update home widget', e);
      });
    } catch (widgetError) {
      AppLogger.e(
          'STATS', 'Failed to get stats for widget update', widgetError);
    }
  }

  return added;
}
