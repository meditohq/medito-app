import 'dart:async';
import 'dart:io';
import 'dart:math';
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
  var backgroundSoundAudioPlayer = AudioPlayer();
  MeditationFilesModel? currentlyPlayingMeditation;
  final hasBgSound = 'hasBgSound';
  final meditationAudioPlayer = AudioPlayer();

  late String _contentToken;

  @override
  Future<void> pause() async {
    pauseBackgroundSound();
    unawaited(meditationAudioPlayer.pause());
  }

  @override
  Future<void> play() async {
    var checkBgAudio = mediaItemHasBGSound();
    if (checkBgAudio) {
      playBackgroundSound();
    } else {
      pauseBackgroundSound();
    }
    unawaited(meditationAudioPlayer.play());
  }

  @override
  Future<void> stop() async {
    unawaited(meditationAudioPlayer.stop());
    if (mediaItemHasBGSound()) {
      stopBackgroundSound();
    }
  }

  void setContentToken(String token) {
    _contentToken = token;
  }

  void initAudioHandler() {
    meditationAudioPlayer.playbackEventStream
        .map(_transformEvent)
        .pipe(playbackState);
  }

  void setBackgroundAudio(BackgroundSoundsModel sound) {
    unawaited(
      backgroundSoundAudioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(sound.path),
          headers: {
            HttpHeaders.authorizationHeader: _contentToken,
          },
        ),
      ),
    );
  }

  void setMeditationAudio(
    MeditationModel meditationModel,
    MeditationFilesModel file, {
    String? filePath,
  }) {
    if (filePath != null) {
      unawaited(meditationAudioPlayer.setFilePath(filePath));
      setMediaItem(meditationModel, file, filePath: filePath);
    } else {
      setMediaItem(meditationModel, file);
      unawaited(
        meditationAudioPlayer.setAudioSource(AudioSource.uri(
          Uri.parse(file.path),
          headers: {
            HttpHeaders.authorizationHeader: _contentToken,
          },
        )),
      );
    }
  }

  void playBackgroundSound() {
    backgroundSoundAudioPlayer.play();
    backgroundSoundAudioPlayer.setLoopMode(LoopMode.all);
  }

  void pauseBackgroundSound() {
    backgroundSoundAudioPlayer.pause();
  }

  void stopBackgroundSound() {
    backgroundSoundAudioPlayer.stop();
  }

  void setMeditationAudioSpeed(double speed) {
    meditationAudioPlayer.setSpeed(speed);
  }

  void seekValueFromSlider(int duration) {
    meditationAudioPlayer.seek(Duration(milliseconds: duration));
  }

  void stopMeditation() {
    meditationAudioPlayer.stop();
  }

  void skipForward30Secs() async {
    var seekDuration = meditationAudioPlayer.position.inMilliseconds +
        Duration(seconds: 30).inMilliseconds;
    await meditationAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void skipBackward10Secs() async {
    var seekDuration = max(
      0,
      meditationAudioPlayer.position.inMilliseconds -
          Duration(seconds: 10).inMilliseconds,
    );
    await meditationAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void setBackgroundSoundVolume(double volume) async {
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }

  void disposeMeditationAudio() async {
    await meditationAudioPlayer.dispose();
  }

  void setMediaItem(
    MeditationModel meditationModel,
    MeditationFilesModel file, {
    String? filePath,
  }) {
    var item = MediaItem(
      id: filePath ?? file.path,
      title: meditationModel.title,
      artist: meditationModel.artist?.name,
      duration: Duration(milliseconds: file.duration),
      artUri: Uri.parse(
        meditationModel.coverUrl,
      ),
      extras: {
        hasBgSound: meditationModel.hasBackgroundSound,
        'meditationId': meditationModel.id,
        'fileId': file.id,
      },
    );
    mediaItem.add(item);
  }

  bool mediaItemHasBGSound() {
    return mediaItem.value?.extras?[hasBgSound] ?? false;
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (meditationAudioPlayer.playing)
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
      }[meditationAudioPlayer.processingState]!,
      playing: meditationAudioPlayer.playing,
      updatePosition: meditationAudioPlayer.position,
      bufferedPosition: meditationAudioPlayer.bufferedPosition,
      speed: meditationAudioPlayer.speed,
      queueIndex: event.currentIndex,
    );
  }
}