import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/types/type_constants.dart';
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
}) async {
  try {
    // First try to sync with HealthKit
    await _syncHealthKit(payload).catchError((e) {
      AppLogger.e('STATS', 'HealthKit sync error', e);
      // Continue even if HealthKit sync fails
    });

    // Then update local stats
    var statsManager = StatsManager()..initialize();

    var newAudioCompleted = LocalAudioCompleted(
      id: payload[TypeConstants.trackIdKey],
      timestamp: payload[TypeConstants.timestampIdKey],
    );

    var duration = payload[TypeConstants.durationIdKey];

    await statsManager.addAudioCompleted(newAudioCompleted, duration);
    AppLogger.d('STATS',
        'Stats updated successfully for track ${newAudioCompleted.id}');

    // Update widgets with new stats data
    try {
      var allStats = await statsManager.localAllStats;
      await updateWidgets(allStats);
      AppLogger.d('STATS', 'Widgets updated with latest stats');
    } catch (widgetError) {
      // Don't fail the whole operation if widget update fails
      AppLogger.e('STATS', 'Failed to update widgets', widgetError);
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
