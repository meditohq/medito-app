import 'dart:async';
import 'dart:io';

import 'package:Medito/audioplayer/media_lib.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/auth.dart';
import 'package:Medito/network/cache.dart';
import 'package:Medito/utils/utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

//This is the duration of bgSound fade towards the end.
const fadeDuration = 20;
const PLAY_BG_SOUND = 'play_bg_sound';
const SEND_BG_SOUND = 'send_bg_sound';
const INIT_BG_SOUND = 'init_bg_sound';
const SET_BG_SOUND_VOL = 'set_bg_sound_vol';
const STOP = 'stop';
const STATS = 'stats';


/// This task defines logic for playing a list of podcast episodes.
class AudioPlayerTask extends BackgroundAudioTask {
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final AudioPlayer _bgPlayer = AudioPlayer(handleInterruptions: false);
  AudioProcessingState _skipState;
  StreamSubscription<PlaybackEvent> _eventSubscription;
  var _duration = Duration();

  var _currentlyPlayingBGSound = '';

  int get index => _player.currentIndex;
  MediaItem mediaItem;
  var initialBgVolume = 0.4;
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
      await getDownload(mediaItem.extras[LOCATION]).then((data) async {
        // (data == null) is true if this session has not been downloaded
        if (data == null) {
          var url = '${BASE_URL}assets/${mediaItem.id}';
          _duration = await _player.setUrl(url,
              headers: {HttpHeaders.authorizationHeader: CONTENT_TOKEN});
        } else {
          _duration = await _player.setFilePath(data);
        }

        if (_duration == null || _duration.inMilliseconds < 1000) {
          //sometimes this library returns incorrect durations
          _duration = Duration(milliseconds: mediaItem.extras['duration']);
        }
      });
    } catch (e) {
      print('Error: $e');
      await onStop();
    }

    // Broadcast media item changes.
    _player.currentIndexStream.listen((index) {
      if (index != null) {
        var newMediaItem = mediaItem.copyWith(duration: _duration);
        mediaItem = newMediaItem;
        AudioServiceBackground.setMediaItem(newMediaItem);
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
    if (_currentlyPlayingBGSound.isNotEmptyAndNotNull()) {
      _bgPlayer.play();
    }
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
      case SET_BG_SOUND_VOL:
        await _bgPlayer.setVolume(params);
        initialBgVolume = params;
        break;
      case PLAY_BG_SOUND:
        await playBgMusic(params);
        break;
      case STOP:
        await _player.stop();
        await _broadcastState();
        break;
      case INIT_BG_SOUND:
        AudioServiceBackground.sendCustomEvent(
            {SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
      case SEND_BG_SOUND:
        _currentlyPlayingBGSound = params ?? '';
        print('bg sound set to: ' + _currentlyPlayingBGSound);
        AudioServiceBackground.sendCustomEvent(
            {SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
    }
  }

  @override
  Future<Function> onFastForward() => _seekRelative(fastForwardInterval);

  @override
  Future<void> onRewind() => _seekRelative(-rewindInterval);

  @override
  Future<void> onSeekTo(Duration position) {
    _player.seek(position);
    return super.onSeekTo(position);
  }

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

  Future<void> playBgMusic(String bgMusicPath) async {
    if (bgMusicPath.isEmptyOrNull()) {
      await _bgPlayer.pause();
    } else {
      AudioServiceBackground.sendCustomEvent({PLAY_BG_SOUND, bgMusicPath});
      await _bgPlayer.setFilePath(bgMusicPath);
      await _bgPlayer.setVolume(initialBgVolume);
      await _bgPlayer.setLoopMode(LoopMode.all);
      await _bgPlayer.play();
    }
  }

  Future<void> updateStats() async {
    var dataMap = {
      'secsListened': _duration.inSeconds,
      'id': '${mediaItem.extras[SESSION_ID]}',
    };
    await writeJSONToCache(encoded(dataMap), STATS);
    AudioServiceBackground.sendCustomEvent(STATS);
  }
}
