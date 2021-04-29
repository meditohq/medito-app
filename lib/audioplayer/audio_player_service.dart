import 'dart:async';
import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/user/user_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pedantic/pedantic.dart';

//This is the duration of bgSound fade towards the end.
const fadeDuration = 20;

/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final AudioPlayer _bgPlayer = AudioPlayer(handleInterruptions: false);
  AudioProcessingState _skipState;
  Seeker _seeker;
  StreamSubscription<PlaybackEvent> _eventSubscription;
  var _duration = Duration();

  int get index => _player.currentIndex;
  MediaItem mediaItem;
  var initialBgVolume = 0.6;
  var _updatedStats = false;

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    var mediaItemJson = params['media'];
    mediaItem = MediaItem.fromJson(mediaItemJson);
    // this bool var is set to true to avoid the volume increase
    var avoidVolumeIncreaseAtLastSec = false;

    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    // Load and broadcast the queue
    await AudioServiceBackground.setQueue([mediaItem]);
    try {
      await getDownload(mediaItem.extras['location']).then((data) async {
        // (data == null) is true if this session has not been downloaded
        if (data == null) {
          var url = '${baseUrl}assets/${mediaItem.id}';
          var auth = await token;
          _duration = await _player.setUrl(url,
              headers: {HttpHeaders.authorizationHeader: auth});
        } else {
          _duration = await _player.setFilePath(data);
        }

        // ignore: null_aware_before_operator
        if (_duration == null || _duration.inMilliseconds < 1000) {
          //sometimes this library returns incorrect durations
          _duration = Duration(milliseconds: mediaItem.extras['duration']);
        }

        String bg = mediaItem.extras['bgMusic'];
        if (bg.isNotEmptyAndNotNull()) {
          playBgMusic(bg);
        }
        unawaited(onPlay());
      });
    } catch (e) {
      print('Error: $e');
      await onStop();
    }

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        AudioServiceBackground.setMediaItem(
            mediaItem.copyWith(duration: _duration));
      }
    });

    _player.positionStream.listen((position) async {
      //ticks on each position
      var timeLeft = _duration.inSeconds - position.inSeconds;
      if (timeLeft == 1) {
        avoidVolumeIncreaseAtLastSec = true;
      }
      if (position != null) {
        if (audioPositionIsInEndPeriod(position)) {
          await setBgVolumeFadeAtEnd(timeLeft);
          if (!_updatedStats) {
            _updatedStats = true;
            await updateStats();
          }
        } else if (audioPositionBeforeEndPeriod(position) &&
            !avoidVolumeIncreaseAtLastSec) {
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

  Future<void> setBgVolumeFadeAtEnd(int timeLeft) async {
    await _bgPlayer.setVolume(initialBgVolume -
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
  Future<void> onCustomAction(String name, dynamic params) async {
    switch (name) {
      case 'setBgVolume':
        initialBgVolume = params;
        break;
      case 'stop':
        await _player.stop();
        await _broadcastState();
        break;
    }
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
    try {
      await _eventSubscription.cancel();
    } catch (e) {
      print('error cancelling');
    }
    try {
      await _player.stop();
      await _broadcastState();
      await _player.dispose();
    } catch (e) {
      print('error cancelling player');
    }
    try {
      await _bgPlayer.stop();
      await _bgPlayer.dispose();
    } catch (e) {
      print('error bg player');
    }
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
    return AudioServiceBackground.setState(
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
      case ProcessingState.idle:
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
        throw Exception('Invalid state: ${_player.processingState}');
    }
  }

  void playBgMusic(String bgMusic) {
    if (bgMusic.isNotEmptyAndNotNull()) {
      _bgPlayer.setFilePath(bgMusic);
      _bgPlayer.setVolume(initialBgVolume);
      _bgPlayer.setLoopMode(LoopMode.all);
    }
  }

  Future<void> updateStats() async {
    var dataMap = {
      'secsListened': _duration.inSeconds,
      'id': '${mediaItem.extras['sessionId']}',
    };
    await writeJSONToCache(encoded(dataMap), 'stats');
    AudioServiceBackground.sendCustomEvent('stats');
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

  void start() async {
    _running = true;
    while (_running) {
      var newPosition = player.position + positionInterval;
      if (newPosition < Duration.zero) newPosition = Duration.zero;
      if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
      await player.seek(newPosition);
      await Future.delayed(stepInterval);
    }
  }

  void stop() {
    _running = false;
  }
}
