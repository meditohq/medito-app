import 'dart:async';
import 'dart:io';

import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../network/auth.dart';
import '../network/cache.dart';
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
  final _player = AudioPlayer();
  final _bgPlayer = AudioPlayer();
  Duration _duration;
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
      }[_player.processingState],
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
      if (_currentlyPlayingBGSound.isNotEmptyAndNotNull()) {
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
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<Function> playMediaItem(MediaItem mediaItem) async {

    try {
      super.mediaItem.add(mediaItem);
      await getDownload(mediaItem.extras[LOCATION]).then((data) async {
        if (data == null) {
          // this session has not been downloaded
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

        unawaited(play());
      });
    } catch (e, s) {
      print(s);
    }

    try {
      _player.positionStream.listen((position) async {
        //ticks on each position
        var timeLeft = _duration.inSeconds - position.inSeconds;
        if (position != null) {
          if (_audioPositionIsInEndPeriod(position)) {
            await _setBgVolumeFadeAtEnd(timeLeft);
            if (!_updatedStats) {
              _updatedStats = true;
              await _updateStats();
            }
          } else {
            var vol = await retrieveSavedBgVolume();
            unawaited(_bgPlayer.setVolume(vol));
          }
        }
      });
    } catch (e, s) {
      print(s);
    }

    return null;
  }

  @override
  Future customAction(String name, [Map<String, dynamic> extras]) async {
    switch (name) {
      case SET_BG_SOUND_VOL:
        _bgVolume = extras[SET_BG_SOUND_VOL];
        unawaited(_bgPlayer.setVolume(extras[SET_BG_SOUND_VOL]));
        break;
      case PLAY_BG_SOUND:
        await _playBgSound(extras);
        break;
      case INIT_BG_SOUND:
        customEvent.add({SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
      case SEND_BG_SOUND:
        _currentlyPlayingBGSound = extras[SEND_BG_SOUND] ?? '';
        customEvent.add({SEND_BG_SOUND: _currentlyPlayingBGSound});
        break;
    }

    return super.customAction(name, extras);
  }

  Future<void> _playBgSound(Map<String, dynamic> extras) async {
    var bgSound = extras[PLAY_BG_SOUND];
    if (bgSound != null) {
      unawaited(_bgPlayer.setFilePath(extras[PLAY_BG_SOUND]));
      unawaited(_bgPlayer.play());
    }
  }

  Future<void> _updateStats() async {
    var dataMap = {
      'secsListened': _duration.inSeconds,
      'id': '${mediaItem.value.extras[SESSION_ID]}',
    };
    await writeJSONToCache(encoded(dataMap), STATS);
    customEvent.add(STATS);
  }

  bool _audioPositionIsInEndPeriod(Duration position) {
    return _duration.inSeconds > 0 &&
        position.inSeconds > _duration.inSeconds - FADE_DURATION;
  }

  Future<void> _setBgVolumeFadeAtEnd(int timeLeft) async {
    unawaited(_bgPlayer.setVolume(_bgVolume -
        ((FADE_DURATION - timeLeft) * (_bgVolume / FADE_DURATION))));
  }
}
