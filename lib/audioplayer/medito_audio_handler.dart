import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../network/auth.dart';
import '../network/cache.dart';
import '../utils/bgvolume_utils.dart';
import 'media_lib.dart';
import 'player_utils.dart';

//This is the duration of bgSound fade towards the end.
const FADE_DURATION = 20;
const PLAY_BG_SOUND = 'play_bg_sound';
const SEND_BG_SOUND = 'send_bg_sound';
const AUDIO_COMPLETE = 'audio_complete';
const INIT_BG_SOUND = 'init_bg_sound';
const SET_BG_SOUND_VOL = 'set_bg_sound_vol';
const STOP = 'stop';
const STATS = 'stats';
const NONE = 'No Sound';

class MeditoAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer(handleInterruptions: false);
  final _bgPlayer = AudioPlayer();
  Duration? _duration;
  var _currentlyPlayingBGSound = '';
  var _updatedStats = false;
  var _bgVolume;

  MeditoAudioHandler() {
    AudioSession.instance.then(
        (session) => session.configure(AudioSessionConfiguration.speech()));
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() async {
    try {
      if (_currentlyPlayingBGSound.isNotEmptyAndNotNull() &&
          mediaItemHasBGSound()) {
        unawaited(_bgPlayer.play());
        unawaited(_bgPlayer.setLoopMode(LoopMode.all));
      }
    } catch (e) {
      print(e);
    }
    unawaited(_player.play().then((value) {
      if (_player.processingState == ProcessingState.completed) {
        customEvent.add({AUDIO_COMPLETE: true});
      }
    }).catchError((err) {
      print(err);
    }));
  }

  @override
  Future<void> pause() async {
    await _bgPlayer.pause();
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    _updatedStats = false;
    await _bgPlayer.pause();
    await _bgPlayer.seek(Duration.zero);
    await _player.pause();
    await _player.seek(Duration.zero);
    // await _player.dispose();
    // await _bgPlayer.dispose();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    try {
      super.mediaItem.add(mediaItem);
      String? getLocation = mediaItem.extras?[LOCATION];
      var data = getLocation != null ? await getDownload(getLocation) : null;
      if (data == null) {
        // this session has not been downloaded
        // TODO
        // var url = '${HTTPConstants.TEST_BASE_URL}assets/${mediaItem.id}';
        var url = '$mediaItem.id}';
        _duration = await _player.setUrl(url,
            headers: {HttpHeaders.authorizationHeader: CONTENT_TOKEN});
      } else {
        _duration = await _player.setFilePath(data);
      }

      if (_duration == null || (_duration?.inMilliseconds ?? 0) < 1000) {
        //sometimes this library returns incorrect durations
        _duration = Duration(milliseconds: mediaItem.extras?['duration']);
      }

      unawaited(play());
    } catch (e, s) {
      print(s);
    }

    try {
      _player.positionStream.listen((position) async {
        //ticks on each position
        var timeLeft = _duration?.inSeconds ?? 0 - position.inSeconds;
        if (_audioPositionIsInEndPeriod(position)) {
          if (_bgPlayer.playing) {
            unawaited(_setBgVolumeFadeAtEnd(timeLeft));
          }
          if (!_updatedStats) {
            _updatedStats = true;
            await _updateStats();
          }
        } else {
          // If the volume has started to fade, but then you select another point in the track
          unawaited(_bgPlayer.setVolume(_bgVolume));
        }
      });
    } catch (e, s) {
      print(s);
    }

    return;
  }

  @override
  Future<dynamic> customAction(String name,
      [Map<String, dynamic>? extras]) async {
    switch (name) {
      case SET_BG_SOUND_VOL:
        _bgVolume = extras?[SET_BG_SOUND_VOL] ?? DEFAULT_VOLUME;
        print('set bg volume' + _bgVolume.toString());
        unawaited(_bgPlayer.setVolume(_bgVolume));
        break;
      case PLAY_BG_SOUND:
        await _playBgSound(extras);
        break;
      case INIT_BG_SOUND:
        _bgVolume = extras?[SET_BG_SOUND_VOL] ?? DEFAULT_VOLUME;
        print('init' + _bgVolume.toString());
        customEvent.add({SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
      case SEND_BG_SOUND:
        _currentlyPlayingBGSound = extras?[SEND_BG_SOUND] ?? NONE;
        customEvent.add({SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
    }

    return super.customAction(name, extras);
  }

  Future<void> _playBgSound(Map<String, dynamic>? extras) async {
    var bgSound = extras?[PLAY_BG_SOUND];
    if (bgSound != null) {
      unawaited(_bgPlayer.setFilePath(extras?[PLAY_BG_SOUND]));
      unawaited(_bgPlayer.play());
    }
  }

  Future<void> _updateStats() async {
    var dataMap = {
      'secsListened': (_duration?.inSeconds ?? 0),
      'id': '${mediaItem.value?.extras?[SESSION_ID] ?? ''}',
    };
    await writeJSONToCache(encoded(dataMap), STATS);
    customEvent.add(STATS);
  }

  bool _audioPositionIsInEndPeriod(Duration position) {
    return (_duration?.inSeconds ?? 0) > 0 &&
        position.inSeconds > (_duration?.inSeconds ?? 0) - FADE_DURATION;
  }

  Future<void> _setBgVolumeFadeAtEnd(int timeLeft) async {
    print(_bgPlayer.volume - (_bgVolume / FADE_DURATION));
    if (_bgPlayer.volume > 0) {
      unawaited(
          _bgPlayer.setVolume(_bgPlayer.volume - (_bgVolume / FADE_DURATION)));
    }
  }

  void skipForward30Secs() {
    var seekDuration = min(_duration?.inMilliseconds ?? 0,
        _player.position.inMilliseconds + Duration(seconds: 30).inMilliseconds);
    _player.seek(Duration(milliseconds: seekDuration));
  }

  void skipBackward10Secs() {
    var seekDuration = max(0,
        _player.position.inMilliseconds - Duration(seconds: 10).inMilliseconds);
    _player.seek(Duration(milliseconds: seekDuration));
  }

  void setPlayerSpeed(double speed) => _player.setSpeed(speed);

  bool mediaItemHasBGSound() => mediaItem.value?.extras?[HAS_BG_SOUND];
}
