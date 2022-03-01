import 'dart:async';
import 'dart:io';

import 'package:Medito/audioplayer/audio_player_service.dart';
import 'package:Medito/utils/utils.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../../audioplayer/media_lib.dart';
import '../../../audioplayer/player_utils.dart';
import '../../../network/auth.dart';
import '../../../network/cache.dart';

class MeditoAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final _player = AudioPlayer();
  final _bgPlayer = AudioPlayer();
  Duration _duration;
  var _currentlyPlayingBGSound = '';
  var _updatedStats = false;
  var _initialBgVolume = 0.4;

  MeditoAudioHandler() {
    AudioSession.instance.then(
        (session) => session.configure(AudioSessionConfiguration.speech()));
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
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
    unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    try {
      unawaited(_bgPlayer.pause());
    } catch (e) {
      print(e);
    }
    unawaited(_player.pause());
  }

  @override
  Future<void> stop() async {
    _updatedStats = false;
    try {
      unawaited(_bgPlayer.stop());
    } catch (e) {
      print(e);
    }
    unawaited(_player.stop());
    await _player.dispose();
    await _bgPlayer.dispose();
  }

  @override
  Future<void> seek(Duration position) async {
    unawaited(_player.seek(position));
  }

  @override
  Future<Function> playMediaItem(MediaItem mediaItem) async {
    var avoidVolumeIncreaseAtLastSec = false;

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
        if (timeLeft == 1) {
          avoidVolumeIncreaseAtLastSec = true;
        }
        if (position != null) {
          if (_audioPositionIsInEndPeriod(position)) {
            await _setBgVolumeFadeAtEnd(timeLeft);
            if (!_updatedStats) {
              _updatedStats = true;
              await _updateStats();
            }
          } else if (_audioPositionBeforeEndPeriod(position) &&
              !avoidVolumeIncreaseAtLastSec) {
            unawaited(_bgPlayer.setVolume(_initialBgVolume));
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
        _initialBgVolume = extras[SET_BG_SOUND_VOL];
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
      unawaited(_bgPlayer.setUrl(extras[PLAY_BG_SOUND]));
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

  bool _audioPositionBeforeEndPeriod(Duration position) {
    //also makes sure the audio has started
    return _duration.inSeconds > 0 &&
        position.inSeconds <= _duration.inSeconds - fadeDuration;
  }

  bool _audioPositionIsInEndPeriod(Duration position) {
    return _duration.inSeconds > 0 &&
        position.inSeconds > _duration.inSeconds - fadeDuration;
  }

  Future<void> _setBgVolumeFadeAtEnd(int timeLeft) async {
    unawaited(_bgPlayer.setVolume(_initialBgVolume -
        ((fadeDuration - timeLeft) * (_initialBgVolume / fadeDuration))));
  }
}
