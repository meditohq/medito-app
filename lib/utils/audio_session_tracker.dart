import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/strings/analytics_event_constants.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../services/analytics/firebase_analytics_service.dart';
import 'logger.dart';

/// Owns the lifecycle of a single in-flight meditation session for analytics,
/// firing [AnalyticsEventConstants.audioSessionStarted] when playback begins and
/// [AnalyticsEventConstants.audioSessionAbandoned] when a session ends without
/// completing. Completion itself is still logged by `handleStats`
/// (stats_updater.dart); this tracker only needs to be told it happened via
/// [onCompleted] so it doesn't also fire "abandoned".
///
/// This is the single source of truth for the started/abandoned events on both
/// platforms — wiring points (player_provider, audio_state_provider, main.dart,
/// player_view) just forward lifecycle signals here. See
/// ANALYTICS_SESSION_EVENTS.md for the full spec and exact fire conditions.
///
/// Reliability: an in-progress record is persisted to SharedPreferences and the
/// last playback position is kept up to date (throttled), so a force-quit that
/// sends no event is recovered as an abandoned event on the next launch via
/// [replayIfAbandoned].
class AudioSessionTracker {
  AudioSessionTracker._();
  static final AudioSessionTracker instance = AudioSessionTracker._();

  /// Sink for the analytics events. Defaults to Firebase; overridable in tests
  /// to capture what would be logged without touching a real analytics client.
  static Future<void> Function(String name, Map<String, Object> parameters)
      logSink = (name, parameters) =>
          FirebaseAnalyticsService().logEvent(name: name, parameters: parameters);

  // Active session, or null when nothing is playing.
  _Session? _active;

  /// How often, at most, the persisted record's position is rewritten. We do
  /// NOT persist on every position tick — that would be needless disk churn.
  static const _persistThrottle = Duration(seconds: 3);
  DateTime? _lastPersistAt;

  /// Called from `PlayerProvider.play()` when a track starts. If a prior session
  /// is still active (the user switched tracks without it completing), that one
  /// is abandoned first.
  Future<void> onStarted({
    required String fileId,
    String? guide,
    required int durationMs,
  }) async {
    // Switching tracks: the previous session never completed.
    if (_active != null && !_active!.ended) {
      await _abandon(reason: 'switch_track');
    }

    final session = _Session(
      fileId: fileId,
      guide: (guide == null || guide.isEmpty) ? 'unknown' : guide,
      durationMs: durationMs,
      startMs: DateTime.now().millisecondsSinceEpoch,
    );
    _active = session;
    _lastPersistAt = null;
    await _persist(session);

    await _log(
      AnalyticsEventConstants.audioSessionStarted,
      {
        AnalyticsEventConstants.paramAudioFileId: session.fileId,
        AnalyticsEventConstants.paramAudioFileGuide: session.guide,
        AnalyticsEventConstants.paramAudioFileDuration: session.durationMs,
      },
    );
    AppLogger.d('SESSION', 'audio_session_started: ${session.fileId}');
  }

  /// Fed by the position stream (~1/s on both platforms). Keeps the last known
  /// position so an abandon knows where the user was, refines the duration once
  /// the player reports a measured value, and notes whether the player has
  /// completed (so a racing stop() doesn't get logged as abandoned).
  void onPositionUpdate({
    required int positionMs,
    required int durationMs,
    required bool isPlaying,
    required bool isCompleted,
  }) {
    final session = _active;
    if (session == null || session.ended) return;

    if (positionMs >= 0) session.lastPositionMs = positionMs;
    // The live, measured duration is authoritative (matches the completed
    // event); only trust positive values.
    if (durationMs > 0) session.durationMs = durationMs;
    session.isPlaying = isPlaying;
    if (isCompleted) session.playerCompleted = true;

    // Throttled persistence — cheap recovery point for a force-quit.
    final now = DateTime.now();
    if (_lastPersistAt == null ||
        now.difference(_lastPersistAt!) >= _persistThrottle) {
      _persist(session);
    }
  }

  /// Called from `handleStats` when a session completes. Clears the record and
  /// guards against a subsequent abandon for the same session.
  Future<void> onCompleted() async {
    final session = _active;
    if (session != null) {
      session.ended = true;
      session.playerCompleted = true;
    }
    await _clearPersisted();
    AppLogger.d('SESSION', 'session completed; cleared in-progress record');
  }

  /// Player closed via the player's stop/close control. Abandonment unless the
  /// session already completed.
  Future<void> onStopped() => _abandon(reason: 'stopped');

  /// PlayerView was disposed (e.g. system back gesture). Only an abandon if the
  /// session is paused — if it's still playing it continues in the background.
  Future<void> onPlayerClosed() async {
    final session = _active;
    if (session == null || session.ended) return;
    if (session.isPlaying) return;
    await _abandon(reason: 'navigate_away');
  }

  /// App went to the background. Same rule as [onPlayerClosed]: a session that
  /// is actively playing keeps going (screen-off mid-meditation is normal), so
  /// only a paused session counts as abandoned here.
  Future<void> onAppBackgrounded() async {
    final session = _active;
    if (session == null || session.ended) return;
    if (session.isPlaying) return;
    await _abandon(reason: 'backgrounded');
  }

  /// Run once early on app launch. If a prior run left an in-progress record
  /// (force-quit / OS-kill), fire the abandoned event from it and clear it.
  Future<void> replayIfAbandoned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw =
          prefs.getString(SharedPreferenceConstants.incompleteAudioSession);
      if (raw == null || raw.isEmpty) return;

      // Clear first so a crash mid-replay can't loop on the same record.
      await prefs.remove(SharedPreferenceConstants.incompleteAudioSession);

      final session = _Session.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
      await _fireAbandoned(session, reason: 'launch_replay');
      AppLogger.d('SESSION',
          'replayed abandoned session from previous launch: ${session.fileId}');
    } catch (e) {
      AppLogger.e('SESSION', 'Failed to replay abandoned session', e);
    }
  }

  /// Drops the in-memory active session. Tests only — the singleton otherwise
  /// leaks state between cases.
  @visibleForTesting
  void resetForTesting() {
    _active = null;
    _lastPersistAt = null;
  }

  // --- internals -----------------------------------------------------------

  Future<void> _abandon({required String reason}) async {
    final session = _active;
    if (session == null || session.ended) return;
    session.ended = true;

    // Player reached the end (or is about to) — that's a completion, which is
    // logged elsewhere; don't double-count it as an abandon.
    if (session.playerCompleted) {
      await _clearPersisted();
      return;
    }

    await _fireAbandoned(session, reason: reason);
    await _clearPersisted();
  }

  Future<void> _fireAbandoned(_Session session,
      {required String reason}) async {
    final elapsedMs =
        session.lastPositionMs < 0 ? 0 : session.lastPositionMs;
    final elapsedSeconds = (elapsedMs / 1000).round();
    final percent = _bucketedPercent(elapsedMs, session.durationMs);

    await _log(
      AnalyticsEventConstants.audioSessionAbandoned,
      {
        AnalyticsEventConstants.paramAudioFileId: session.fileId,
        AnalyticsEventConstants.paramAudioFileGuide: session.guide,
        AnalyticsEventConstants.paramAudioFileDuration: session.durationMs,
        AnalyticsEventConstants.paramPercentCompleted: percent,
        AnalyticsEventConstants.paramElapsedSeconds: elapsedSeconds,
        AnalyticsEventConstants.paramReason: reason,
      },
    );
    AppLogger.d('SESSION',
        'audio_session_abandoned ($reason): ${session.fileId} @ $percent% / ${elapsedSeconds}s');
  }

  /// Percent of [durationMs] reached, rounded to the nearest 10 and clamped to
  /// 0..90 (a session at ~100% is a completion, not an abandon).
  int _bucketedPercent(int positionMs, int durationMs) {
    if (durationMs <= 0) return 0;
    final raw = (positionMs / durationMs) * 100;
    final rounded = (raw / 10).round() * 10;
    if (rounded < 0) return 0;
    if (rounded > 90) return 90;
    return rounded;
  }

  Future<void> _persist(_Session session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        SharedPreferenceConstants.incompleteAudioSession,
        jsonEncode(session.toJson()),
      );
      _lastPersistAt = DateTime.now();
    } catch (e) {
      AppLogger.e('SESSION', 'Failed to persist in-progress session', e);
    }
  }

  Future<void> _clearPersisted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(SharedPreferenceConstants.incompleteAudioSession);
    } catch (e) {
      AppLogger.e('SESSION', 'Failed to clear in-progress session', e);
    }
  }

  Future<void> _log(String name, Map<String, Object> parameters) async {
    try {
      await logSink(name, parameters);
    } catch (e) {
      AppLogger.e('SESSION', 'Failed to log $name', e);
    }
  }
}

class _Session {
  _Session({
    required this.fileId,
    required this.guide,
    required this.durationMs,
    required this.startMs,
    this.lastPositionMs = 0,
  });

  final String fileId;
  final String guide;
  int durationMs;
  final int startMs;
  int lastPositionMs;

  // Runtime-only flags (not persisted).
  bool ended = false;
  bool isPlaying = true;
  bool playerCompleted = false;

  Map<String, dynamic> toJson() => {
        'fileId': fileId,
        'guide': guide,
        'durationMs': durationMs,
        'startMs': startMs,
        'lastPositionMs': lastPositionMs,
      };

  factory _Session.fromJson(Map<String, dynamic> json) => _Session(
        fileId: (json['fileId'] as String?) ?? 'unknown',
        guide: (json['guide'] as String?) ?? 'unknown',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        startMs: (json['startMs'] as num?)?.toInt() ?? 0,
        lastPositionMs: (json['lastPositionMs'] as num?)?.toInt() ?? 0,
      );
}
