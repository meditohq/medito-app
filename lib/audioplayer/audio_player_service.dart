import 'dart:async';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import 'media_lib.dart';

//This is the duration of bgSound fade towards the end.
const fadeDuration = 20;

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  AudioPlayer _player = new AudioPlayer(handleInterruptions: false);
  AudioPlayer _bgPlayer = new AudioPlayer(handleInterruptions: false);
  AudioProcessingState _skipState;
  Seeker _seeker;
  StreamSubscription<PlaybackEvent> _eventSubscription;
  var _duration = Duration();

  int get index => _player.currentIndex;
  MediaItem mediaItem;
  var initialBgVolume = 0.4;
  var _updatedStats = false;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    await MediaLibrary.retrieveMediaLibrary().then((value) {
      this.mediaItem = value;
    });

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    // Load and broadcast the queue
    AudioServiceBackground.setQueue([mediaItem]);
    try {
      await getDownload(mediaItem.extras['location']).then((data) async {
        // (data == null) is true if this session has not been downloaded
        if (data == null) {
          _duration = await _player.setUrl(mediaItem.id);
        } else {
          _duration = await _player.setFilePath(data);
        }

        if (_duration.inMilliseconds < 1000) {
          //sometimes this library returns incorrect durations
          _duration = Duration(milliseconds: mediaItem.extras['duration']);

        }

        playBgMusic(mediaItem.extras['bgMusic']);
        onPlay();
      });
    } catch (e) {
      print("Error: $e");
      onStop();
    }

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null)
        AudioServiceBackground.setMediaItem(
            mediaItem.copyWith(duration: _duration));
      return null;
    });

    _player.positionStream.listen((position) async {
      //ticks on each position
      if (position != null) {
        if (audioPositionIsInEndPeriod(position)) {
          await setBgVolumeFadeAtEnd(
              mediaItem, position.inSeconds, _duration.inSeconds);
          await updateStats();
        } else if (audioPositionBeforeEndPeriod(position)) {
          await _bgPlayer.setVolume(initialBgVolume);
        }
      }
    });

    // Propagate all events from the audio player to AudioService clients.
    _eventSubscription = _player.playbackEventStream.listen((event) {
      _broadcastState();
    });
    // Special processing for state transitions.
    _player.processingStateStream.listen((state) {
      switch (state) {
        case ProcessingState.completed:
          // In this example, the service stops when reaching the end.
          onStop();
          break;
        case ProcessingState.ready:
          // If we just came from skipping between tracks, clear the skip
          // state now that we're ready to play.
          _skipState = null;
          break;
        default:
          break;
      }
    });
  }

  bool audioPositionBeforeEndPeriod(Duration position) {
    //also makes sure the audio has started
    return _duration.inSeconds > 0 &&
        position.inSeconds <= _duration.inSeconds - fadeDuration;
  }

  bool audioPositionIsInEndPeriod(Duration position) {
    return _duration.inSeconds > 0 &&
        position.inSeconds > _duration.inSeconds - fadeDuration;
  }

  Future<void> setBgVolumeFadeAtEnd(
      MediaItem mediaItem, int positionSecs, int durSecs) async {
    var timeLeft = durSecs - positionSecs;
    await _bgPlayer.setVolume(initialBgVolume -
        ((fadeDuration - timeLeft) * (initialBgVolume / fadeDuration)));
    print(initialBgVolume -
        ((fadeDuration - timeLeft) * (initialBgVolume / fadeDuration)));
  }

  @override
  Future<void> onPlay() {
    _bgPlayer.play();
    return _player.play();
  }

  @override
  Future<void> onPause() {
    _bgPlayer.pause();
    return _player.pause();
  }

  @override
  Future<void> onSeekTo(Duration position) => _player.seek(position);

  @override
  Future<void> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekForward(bool begin) async => _seekContinuously(begin, 1);

  @override
  Future<void> onSeekBackward(bool begin) async => _seekContinuously(begin, -1);

  @override
  Future<void> onStop() async {
    // It is important to wait for this state to be broadcast before we shut
    // down the task. If we don't, the background task will be destroyed before
    // the message gets sent to the UI.
    await _player.stop();
    await _bgPlayer.stop();
    await _broadcastState();
    await _player.dispose();
    await _bgPlayer.dispose();
    _eventSubscription.cancel();
    // Shut down this task
    await super.onStop();
  }

  /// Jumps away from the current position by [offset].
  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _player.position + offset;
    // Make sure we don't jump out of bounds.
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
    // Perform the jump via a seek.
    await _player.seek(newPosition);
  }

  /// Begins or stops a continuous seek in [direction]. After it begins it will
  /// continue seeking forward or backward by 10 seconds within the audio, at
  /// intervals of 1 second in app time.
  void _seekContinuously(bool begin, int direction) {
    _seeker?.stop();
    if (begin) {
      _seeker = Seeker(_player, Duration(seconds: 10 * direction),
          Duration(seconds: 1), mediaItem)
        ..start();
    }
  }

  /// Broadcasts the current state to all clients.
  Future<void> _broadcastState() async {
    await AudioServiceBackground.setState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: [
        MediaAction.seekTo,
      ],
      processingState: _getProcessingState(),
      playing: _player.playing,
      position: _player.position ?? Duration(),
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    );
  }

  /// Maps just_audio's processing state into into audio_service's playing
  /// state. If we are in the middle of a skip, we use [_skipState] instead.
  AudioProcessingState _getProcessingState() {
    if (_skipState != null) return _skipState;
    switch (_player.processingState) {
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
        throw Exception("Invalid state: ${_player.processingState}");
    }
  }

  void playBgMusic(String bgMusic) {
    if (bgMusic != null && bgMusic.isNotEmpty && bgMusic != "null") {
      _bgPlayer.setFilePath(bgMusic);
      _bgPlayer.setVolume(initialBgVolume);
      _bgPlayer.setLoopMode(LoopMode.one);
    }
  }

  Future<void> updateStats() async {
    if (!_updatedStats) {
      _updatedStats = true;

      var dataMap = {
        'secsListened': _duration.inSeconds,
        'id': '${mediaItem.extras['id']}',
      };

      await writeJSONToCache(encoded(dataMap), "stats");

      AudioServiceBackground.sendCustomEvent('');
    }
  }
}

class Seeker {
  final AudioPlayer player;
  final Duration positionInterval;
  final Duration stepInterval;
  final MediaItem mediaItem;
  bool _running = false;

  Seeker(
    this.player,
    this.positionInterval,
    this.stepInterval,
    this.mediaItem,
  );

  start() async {
    _running = true;
    while (_running) {
      Duration newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  stop() {
    _running = false;
  }
}
