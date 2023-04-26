import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/main.dart';
import 'package:Medito/models/models.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final audioPlayerNotifierProvider =
    ChangeNotifierProvider<AudioPlayerNotifier>((ref) {
  return audioHandler;
});

//ignore:prefer-match-file-name
class AudioPlayerNotifier extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  final backgroundSoundAudioPlayer = AudioPlayer();
  final sessionAudioPlayer = AudioPlayer();
  SessionFilesModel? currentlyPlayingSession;
  final hasBgSound = 'hasBgSound';

  void initAudioHandler() {
    sessionAudioPlayer.playbackEventStream
        .map(_transformEvent)
        .pipe(playbackState);
  }

  void setBackgroundAudio(BackgroundSoundsModel sound) {
    unawaited(backgroundSoundAudioPlayer.setUrl(sound.path, headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
    }));
  }

  void setSessionAudio(
    SessionModel sessionModel,
    SessionFilesModel file, {
    String? filePath,
  }) {
    if (filePath != null) {
      unawaited(sessionAudioPlayer.setFilePath(filePath));
      setMediaItem(sessionModel, file, filePath: filePath);
    } else {
      setMediaItem(sessionModel, file);
      unawaited(sessionAudioPlayer.setUrl(file.path, headers: {
        HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
      }));
    }
  }

  @override
  Future<void> play() async {
    var checkBgAudio = mediaItemHasBGSound();
    if (checkBgAudio) {
      unawaited(playBackgroundSound());
    } else {
      unawaited(pauseBackgroundSound());
    }
    await sessionAudioPlayer.play();
  }

  @override
  Future<void> pause() async {
    unawaited(pauseBackgroundSound());
    await sessionAudioPlayer.pause();
  }

  @override
  Future<void> stop() async {
    await sessionAudioPlayer.stop();
    if (mediaItemHasBGSound()) {
      await stopBackgroundSound();
    }
  }

  Future<void> playBackgroundSound() async {
    unawaited(backgroundSoundAudioPlayer.play());
    await backgroundSoundAudioPlayer.setLoopMode(LoopMode.all);
  }

  Future<void> pauseBackgroundSound() async {
    await backgroundSoundAudioPlayer.pause();
  }

  Future<void> stopBackgroundSound() async {
    await backgroundSoundAudioPlayer.stop();
  }

  void setSessionAudioSpeed(double speed) async {
    await sessionAudioPlayer.setSpeed(speed);
  }

  void seekValueFromSlider(int duration) {
    unawaited(sessionAudioPlayer.seek(Duration(milliseconds: duration)));
  }

  void skipForward30Secs() async {
    var seekDuration = sessionAudioPlayer.position.inMilliseconds +
        Duration(seconds: 30).inMilliseconds;
    await sessionAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void skipBackward10Secs() async {
    var seekDuration = max(
      0,
      sessionAudioPlayer.position.inMilliseconds -
          Duration(seconds: 10).inMilliseconds,
    );
    await sessionAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void setBackgroundSoundVolume(double volume) async {
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }

  void disposeSessionAudio() async {
    await sessionAudioPlayer.dispose();
  }

  void setMediaItem(
    SessionModel sessionModel,
    SessionFilesModel file, {
    String? filePath,
  }) {
    var item = MediaItem(
      id: filePath ?? file.path,
      title: sessionModel.title,
      artist: sessionModel.artist?.name,
      duration: Duration(milliseconds: file.duration),
      artUri: Uri.parse(
        sessionModel.coverUrl,
      ),
      extras: {
        hasBgSound: sessionModel.hasBackgroundSound,
      },
    );
    mediaItem.add(item);
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (sessionAudioPlayer.playing)
          MediaControl.pause
        else
          MediaControl.play,
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
      }[sessionAudioPlayer.processingState]!,
      playing: sessionAudioPlayer.playing,
      updatePosition: sessionAudioPlayer.position,
      bufferedPosition: sessionAudioPlayer.bufferedPosition,
      speed: sessionAudioPlayer.speed,
      queueIndex: event.currentIndex,
    );
  }

  bool mediaItemHasBGSound() {
    return mediaItem.value?.extras?[hasBgSound] ?? false;
  }
}
