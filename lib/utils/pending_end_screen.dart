import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/player/playback_request.dart';
import 'package:medito/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A finished session whose end screen never got to show.
class PendingEndScreenEntry {
  final PlaybackRequest request;
  final LocalAllStats? priorStats;

  /// When the session finished, so the screen can say it was a while ago.
  final DateTime completedAt;

  const PendingEndScreenEntry({
    required this.request,
    required this.completedAt,
    this.priorStats,
  });
}

/// Remembers the session the player is running so its end screen can be
/// rebuilt after the app process dies.
///
/// A session that ends with the screen off only opens its end screen on the
/// next frame, i.e. when the user comes back. If the OS killed the app in
/// between, the next launch went straight to Home and the end screen (stats,
/// reminder ask, donation card) was lost — ~2k users in three weeks of
/// 2609.27+ finished sessions and never saw one (GA4, Oct 2026).
///
/// [PlayerView] writes the record when playback starts and clears it when it
/// goes away (end screen opened, or closed mid-session). Process death skips
/// that clear, so a record that is still here and marked completed means the
/// end screen was never shown. The completion can be recorded before the
/// process dies or replayed by the platform on the next launch; either way
/// [markCompleted] runs from handleStats and notifies [completions].
class PendingEndScreen {
  static const prefsKey = 'pending_end_screen';

  /// Past this, the session is stale and the user has moved on.
  static const maxAge = Duration(hours: 24);

  static const _requestKey = 'request';
  static const _priorStatsKey = 'priorStats';
  static const _startedAtKey = 'startedAt';
  static const _completedAtKey = 'completedAt';

  /// Bumped whenever the running session is marked completed.
  static final completions = ValueNotifier<int>(0);

  static int _livePlayers = 0;

  /// A mounted player opens its own end screen, so nothing needs restoring.
  static bool get hasLivePlayer => _livePlayers > 0;

  static void playerMounted() => _livePlayers++;

  static void playerUnmounted() {
    if (_livePlayers > 0) _livePlayers--;
  }

  static int _liveEndScreens = 0;

  /// The player or its end screen is open. Closing either from outside (e.g.
  /// a notification tap returning to Home) would stop the meditation or lose
  /// its summary, so callers must leave them in place.
  static bool get hasLiveSessionScreen =>
      _livePlayers > 0 || _liveEndScreens > 0;

  static void endScreenMounted() => _liveEndScreens++;

  static void endScreenUnmounted() {
    if (_liveEndScreens > 0) _liveEndScreens--;
  }

  static Future<void> start(
    SharedPreferences prefs,
    PlaybackRequest request,
    LocalAllStats? priorStats, {
    DateTime? now,
  }) async {
    try {
      await prefs.setString(
        prefsKey,
        jsonEncode({
          _requestKey: request.toJson(),
          if (priorStats != null) _priorStatsKey: priorStats.toJson(),
          _startedAtKey: (now ?? DateTime.now()).millisecondsSinceEpoch,
        }),
      );
      AppLogger.d('END_SCREEN', 'Running session saved: ${request.fileId}');
    } catch (e) {
      AppLogger.w('END_SCREEN', 'Could not save running session: $e');
    }
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(prefsKey);
  }

  /// Marks the running session completed if [fileId] is its file and the
  /// completion ([timestampMs]) happened after it started, so a replay of an
  /// older session cannot claim a newer one.
  static Future<void> markCompleted(
    SharedPreferences prefs, {
    required String? fileId,
    required int timestampMs,
  }) async {
    final record = _read(prefs);
    if (record == null || record[_completedAtKey] != null) return;
    final request = record[_requestKey] as Map<String, dynamic>;
    if (fileId == null || request['fileId'] != fileId) return;
    if (timestampMs < (record[_startedAtKey] as int)) return;

    record[_completedAtKey] = timestampMs;
    await prefs.setString(prefsKey, jsonEncode(record));
    AppLogger.d('END_SCREEN', 'Running session completed: $fileId');
    completions.value++;
  }

  /// Returns and clears a completed session whose end screen never showed.
  /// Drops records older than [maxAge].
  static Future<PendingEndScreenEntry?> takeCompleted(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final record = _read(prefs);
    if (record == null) return null;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final completedAt = record[_completedAtKey] as int?;
    final startedAt = record[_startedAtKey] as int;

    if (completedAt == null) {
      // Killed mid-session; a late replay can still complete it.
      if (nowMs - startedAt > maxAge.inMilliseconds) await clear(prefs);
      return null;
    }
    await clear(prefs);
    if (nowMs - completedAt > maxAge.inMilliseconds) return null;

    try {
      final stats = record[_priorStatsKey] as Map<String, dynamic>?;
      return PendingEndScreenEntry(
        request: PlaybackRequest.fromJson(
          record[_requestKey] as Map<String, dynamic>,
        ),
        priorStats: stats == null ? null : LocalAllStats.fromJson(stats),
        completedAt: DateTime.fromMillisecondsSinceEpoch(completedAt),
      );
    } catch (e) {
      AppLogger.w('END_SCREEN', 'Could not restore end screen: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _read(SharedPreferences prefs) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.w('END_SCREEN', 'Dropping unreadable running session: $e');
      prefs.remove(prefsKey);
      return null;
    }
  }
}
