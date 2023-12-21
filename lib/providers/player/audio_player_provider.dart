import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:Medito/main.dart';
import 'package:Medito/models/models.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

final audioPlayerNotifierProvider =
    ChangeNotifierProvider<AudioPlayerNotifier>((ref) {
  return audioHandler;
});

//ignore:prefer-match-file-name
class AudioPlayerNotifier extends BaseAudioHandler
    with QueueHandler, SeekHandler, ChangeNotifier {
  var backgroundSoundAudioPlayer = AudioPlayer();
  final trackAudioPlayer = AudioPlayer();

  TrackFilesModel? currentlyPlayingTrack;
  final hasBgSoundKey = 'hasBgSound';
  final fadeDurationInSeconds = 5;
  var bgVolume;

  @override
  Future<void> pause() async {
    try {
      pauseBackgroundSound();
      unawaited(trackAudioPlayer.pause());
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        stackTrace: err,
      ));
    }
  }

  @override
  Future<void> play() async {
    try {
      unawaited(trackAudioPlayer.play());
      var hasBgSound = mediaItemHasBGSound();
      if (hasBgSound) {
        playBackgroundSound();
      } else {
        pauseBackgroundSound();
      }
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        stackTrace: err,
      ));
    }
  }

  @override
  Future<void> stop() async {
    unawaited(trackAudioPlayer.stop());
    if (mediaItemHasBGSound()) {
      stopBackgroundSound();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    seekValueFromSlider(position.inMilliseconds);
  }

  void initAudioHandler() {
    trackAudioPlayer.playbackEventStream
        .map(_transformEvent)
        .pipe(playbackState);
  }

  void setBackgroundAudio(BackgroundSoundsModel sound) {
    getApplicationDocumentsDirectory().then((file) async {
      var savePath = file.path + '/${sound.title}.mp3';
      var filePath = File(savePath);
      if (await filePath.exists()) {
        unawaited(backgroundSoundAudioPlayer.setFilePath(filePath.path));
      } else {
        unawaited(
          backgroundSoundAudioPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(sound.path),
            ),
          ),
        );
      }
    });
  }

  void setTrackAudio(
    TrackModel trackModel,
    TrackFilesModel file, {
    String? filePath,
  }) {
    try {
      if (filePath != null) {
        unawaited(trackAudioPlayer.setFilePath(filePath));
        setMediaItem(trackModel, file, filePath: filePath);
      } else {
        setMediaItem(trackModel, file);
        trackAudioPlayer.setUrl(file.path);
      }
    } catch (e) {
      unawaited(Sentry.captureException(
        e,
        stackTrace: e,
      ));
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

  void setTrackAudioSpeed(double speed) {
    trackAudioPlayer.setSpeed(speed);
  }

  void seekValueFromSlider(int duration) {
    try {
      trackAudioPlayer.seek(Duration(milliseconds: duration));
    } catch (err) {
      Sentry.captureException(
        err,
        stackTrace: err,
      );
    }
  }

  void skipForward10Secs() async {
    var seekDuration = trackAudioPlayer.position.inMilliseconds +
        Duration(seconds: 10).inMilliseconds;
    await trackAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void skipBackward10Secs() async {
    var seekDuration = max(
      0,
      trackAudioPlayer.position.inMilliseconds -
          Duration(seconds: 10).inMilliseconds,
    );
    await trackAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void setBackgroundSoundVolume(double volume) async {
    bgVolume = volume;
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }

  bool handleFadeAtEnd(
    Duration position,
    Duration maxDuration,
  ) {
    var isEnding = maxDuration.inSeconds > 0 &&
        position.inSeconds > maxDuration.inSeconds - fadeDurationInSeconds;
    if (isEnding) {
      _setBgVolumeFadeAtEnd();
    } else {
      if (bgVolume != null) {
        Future.delayed(Duration(milliseconds: 500), () {
          setBackgroundSoundVolume(bgVolume);
        });
      }
    }

    return isEnding;
  }

  void _setBgVolumeFadeAtEnd() {
    if (backgroundSoundAudioPlayer.volume > 0) {
      Future.delayed(Duration(milliseconds: 500), () {
        var newVolume = backgroundSoundAudioPlayer.volume - 0.05;
        if (newVolume > 0) {
          unawaited(backgroundSoundAudioPlayer.setVolume(newVolume));
        }
      });
    }
  }

  void setMediaItem(
    TrackModel trackModel,
    TrackFilesModel file, {
    String? filePath,
  }) {
    var item = MediaItem(
      id: filePath ?? file.path,
      title: trackModel.title,
      artist: trackModel.artist?.name,
      duration: Duration(milliseconds: file.duration),
      artUri: Uri.parse(
        trackModel.coverUrl,
      ),
      extras: {
        hasBgSoundKey: trackModel.hasBackgroundSound,
        'trackId': trackModel.id,
        'fileId': file.id,
      },
    );
    mediaItem.add(item);
  }

  bool mediaItemHasBGSound() {
    return mediaItem.value?.extras?[hasBgSoundKey] ?? false;
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (trackAudioPlayer.playing) MediaControl.pause else MediaControl.play,
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
      }[trackAudioPlayer.processingState]!,
      playing: trackAudioPlayer.playing,
      updatePosition: trackAudioPlayer.position,
      bufferedPosition: trackAudioPlayer.bufferedPosition,
      speed: trackAudioPlayer.speed,
      queueIndex: event.currentIndex,
    );
  }
}
