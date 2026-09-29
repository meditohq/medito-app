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

  bool get enabled => _enabled;

  Future<void> enable(double volume) async {
    if (_enabled && _ready) return;
    final generation = ++_generation;
    _enabled = true;
    _ready = false;
    _schedule.reset();
    _loading ??= _bell
        .setAsset(kSessionBellAsset)
        .then<void>((_) {})
        .catchError((Object error) {
          _loading = null;
          throw error;
        });
    await _loading;
    if (!_enabled || generation != _generation) return;
    await _bell.setVolume(volume);
    if (!_enabled || generation != _generation) return;
    _ready = true;
    _update();
  }

  void setVolume(double volume) => unawaited(_bell.setVolume(volume));

  void reset() {
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
      unawaited(_ring());
    } else if (_bell.processingState == ProcessingState.ready &&
        !_bell.playing &&
        _bell.position > Duration.zero) {
      unawaited(_bell.play());
    }
  }

  Future<void> _ring() async {
    final generation = _generation;
    try {
      await _bell.seek(Duration.zero);
      if (!_enabled || generation != _generation) return;
      if (!primary.playing ||
          primary.processingState != ProcessingState.ready) {
        return;
      }
      await _bell.play();
    } catch (error) {
      AppLogger.e('BELLS', 'Bell playback failed: $error');
    }
  }
}
