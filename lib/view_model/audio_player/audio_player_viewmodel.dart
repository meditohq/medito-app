import 'dart:async';
import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

final audioPlayerNotifierProvider =
    ChangeNotifierProvider<AudioPlayerNotifier>((ref) {
  return AudioPlayerNotifier();
});

class AudioPlayerNotifier extends ChangeNotifier {
  final backgroundSoundAudioPlayer = AudioPlayer();
  final sessionAudioPlayer = AudioPlayer();


  void setBackgroundAudio(BackgroundSoundsModel sound) async {
    unawaited(backgroundSoundAudioPlayer.setUrl(sound.path, headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
    }));
  }

  void setSessionAudio(BackgroundSoundsModel sound) async {
    unawaited(sessionAudioPlayer.setUrl(sound.path, headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
    }));
  }

  void playBackgroundSound() async {
    unawaited(backgroundSoundAudioPlayer.play());
  }

  void playSessionAudio() async {
    unawaited(sessionAudioPlayer.play());
  }

  void pauseBackgroundSound() async {
    await backgroundSoundAudioPlayer.pause();
  }

  void pauseSessionAudio() async {
    await sessionAudioPlayer.pause();
  }

  void stopBackgroundSound() async {
    await backgroundSoundAudioPlayer.stop();
  }

  void stopSessionAudio() async {
    await sessionAudioPlayer.stop();
  }

  void setSessionAudioSpeed(double speed) async {
    await sessionAudioPlayer.setSpeed(speed);
  }

  void setBackgroundSoundVolume(double volume) async {
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }
}
