import 'dart:async';

import 'package:Medito/audioplayer/audio_player_singleton.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

class MeditoAudioPlayerTask extends BackgroundAudioTask {
  List<MediaControl> getControls(bool playing) {
    return [
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];
  }

  Future<void> onStart(Map<String, dynamic> params) {
    AudioPlayerSingleton()
        .player
        .load(ProgressiveAudioSource(Uri.parse(params['url'])))
        .then((value) {
      AudioPlayerSingleton().duration = value;
      onPlay();
      return null;
    });
    return null;
  }

  // Handle a request to stop audio and finish the task.
  onStop() async {
    await AudioPlayerSingleton().player.stop();
    await  _broadcastState(false);
    super.onStop();
  }

  // Handle a request to play audio.
  onPlay() async {
    await AudioPlayerSingleton().player.play();
    await _broadcastState(true);
  }

  // Handle a request to pause audio.
  onPause() async {
    await AudioPlayerSingleton().player.pause();
    await _broadcastState(false);
  }

  // Handle a headset button click (play/pause, skip next/prev).
  onClick(MediaButton button) {
    AudioPlayerSingleton().player.playing
        ? AudioPlayerSingleton().player.pause()
        : AudioPlayerSingleton().player.play();
  }

  // Handle a request to seek to a position.
  onSeekTo(Duration position) {
    AudioPlayerSingleton().player.seek(position);
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState(bool playing) async {
    await AudioServiceBackground.setState(
      controls: [
        if (playing)
          MediaControl.pause
        else
          MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: [
        MediaAction.seekTo,
      ],
      processingState: _getProcessingState(),
      playing: playing,
      position: AudioPlayerSingleton().player.position,
      bufferedPosition: AudioPlayerSingleton().player.bufferedPosition,
    );
  }

  AudioProcessingState _getProcessingState() {
    switch (AudioPlayerSingleton().player.processingState) {
      case ProcessingState.none:
        return AudioProcessingState.stopped;
      case ProcessingState.loading:
        return AudioProcessingState.connecting;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
      default:
        throw Exception(
            "Invalid state: ${AudioPlayerSingleton().player.processingState}");
    }
  }
}

/// An object that performs interruptable sleep.
class Sleeper {
  Completer _blockingCompleter;

  /// Sleep for a duration. If sleep is interrupted, a
  /// [SleeperInterruptedException] will be thrown.
  Future<void> sleep([Duration duration]) async {
    _blockingCompleter = Completer();
    if (duration != null) {
      await Future.any([Future.delayed(duration), _blockingCompleter.future]);
    } else {
      await _blockingCompleter.future;
    }
    final interrupted = _blockingCompleter.isCompleted;
    _blockingCompleter = null;
    if (interrupted) {
      throw SleeperInterruptedException();
    }
  }

  /// Interrupt any sleep that's underway.
  void interrupt() {
    if (_blockingCompleter?.isCompleted == false) {
      _blockingCompleter.complete();
    }
  }
}

class SleeperInterruptedException {}

class Seeker {
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(
    this.positionInterval,
    this.stepInterval,
    this.mediaItem,
  );

  start() async {
    _running = true;
    while (_running) {
      Duration newPosition =
          AudioPlayerSingleton().player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      AudioPlayerSingleton().player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  stop() {
    _running = false;
  }
}
