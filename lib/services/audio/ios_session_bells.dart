import '../../models/background_sounds/session_bell_pattern.dart';

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../models/background_sounds/background_sounds_model.dart';
import '../../utils/logger.dart';
import 'session_bell_schedule.dart';

/// Owns one-shot bell playback; ambient loops never enter this controller.
class IosSessionBells {
  IosSessionBells(this.primary, {AudioPlayer? bell})
    : _bell = bell ?? AudioPlayer() {
    primary.positionStream.listen((_) => _update());
    primary.playerStateStream.listen((_) => _update());
    primary.positionDiscontinuityStream.listen((event) {
      if (event.reason == PositionDiscontinuityReason.autoAdvance) {
        _schedule.reset();
      } else if (event.reason == PositionDiscontinuityReason.seek) {
        _pendingRing = false;
        unawaited(_bell.pause());
        _schedule.seek(
          primary.position,
          primary.duration ?? Duration.zero,
          speed: primary.speed,
        );
      }
      _update();
    });
  }

  final AudioPlayer primary;
  final AudioPlayer _bell;
  final _schedule = SessionBellSchedule();
  bool _enabled = false;
  bool _ready = false;
  int _generation = 0;
  Future<void>? _loading;

  /// A cue has fired but the bell has not started sounding yet. The schedule
  /// consumes a cue the moment it reports it, so without this a ring that was
  /// abandoned (the primary player stalled for an instant while the bell was
  /// seeking) lost that bell for the whole session.
  bool _pendingRing = false;
  bool _ringInFlight = false;

  bool get enabled => _enabled;

  Future<void> enable(
    double volume, {
    SessionBellPattern pattern = SessionBellPattern.beginningMiddleEnd,
    int intervalSeconds = 0,
  }) async {
    if (_enabled &&
        _ready &&
        _schedule.pattern == pattern &&
        _schedule.intervalSeconds == intervalSeconds) {
      await _bell.setVolume(volume);
      return;
    }
    _schedule.pattern = pattern;
    _schedule.intervalSeconds = intervalSeconds;
    final generation = ++_generation;
    _enabled = true;
    _ready = false;
    _schedule.reset();
    // A load can be interrupted (a stop from the session that just ended
    // landing mid-load). Left alone that kept the bells silent until they were
    // switched off and on again, so try once more before giving up.
    for (var attempt = 0; ; attempt++) {
      final loading = _loading ??= _bell
          .setAsset(kSessionBellAsset)
          .then<void>((_) {});
      try {
        await loading;
        break;
      } catch (error) {
        if (identical(_loading, loading)) _loading = null;
        if (!_enabled || generation != _generation) return;
        if (attempt >= 1) rethrow;
        AppLogger.w('BELLS', 'Bell failed to load, retrying: $error');
      }
    }
    if (!_enabled || generation != _generation) return;
    await _bell.setVolume(volume);
    if (!_enabled || generation != _generation) return;
    _ready = true;
    _update();
  }

  void setVolume(double volume) => unawaited(_bell.setVolume(volume));

  void reset() {
    _pendingRing = false;
    _schedule.reset();
    unawaited(_bell.pause());
  }

  Future<void> disable() async {
    _generation++;
    _enabled = false;
    _ready = false;
    reset();
    _loading = null;
    await _bell.stop();
  }

  void _update() {
    if (!_enabled || !_ready) return;
    if (primary.processingState == ProcessingState.completed) {
      _pendingRing = false;
      unawaited(_bell.pause());
      return;
    }
    if (!primary.playing || primary.processingState != ProcessingState.ready) {
      unawaited(_bell.pause());
      return;
    }
    if (_schedule.update(
      primary.position,
      primary.duration ?? Duration.zero,
      speed: primary.speed,
    )) {
      _pendingRing = true;
    }
    if (_pendingRing) {
      if (!_ringInFlight) unawaited(_ring());
    } else if (_bell.processingState == ProcessingState.ready &&
        !_bell.playing &&
        _bell.position > Duration.zero) {
      unawaited(_bell.play());
    }
  }

  Future<void> _ring() async {
    final generation = _generation;
    _ringInFlight = true;
    try {
      await _bell.seek(Duration.zero);
      if (!_enabled || generation != _generation) return;
      // Not playing right now: stay pending, the next update rings it.
      if (!primary.playing ||
          primary.processingState != ProcessingState.ready) {
        return;
      }
      _pendingRing = false;
      _ringInFlight = false;
      await _bell.play();
    } catch (error) {
      _pendingRing = false;
      AppLogger.e('BELLS', 'Bell playback failed: $error');
    } finally {
      _ringInFlight = false;
    }
  }
}
