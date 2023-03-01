import 'dart:async';
import 'dart:io';
import 'dart:math';

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

  void setSessionAudio(String path) async {
    unawaited(sessionAudioPlayer.setUrl(path, headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
    }));
  }

  void playBackgroundSound() async {
    unawaited(backgroundSoundAudioPlayer.play());
  }

  void playSessionAudio() async {
    unawaited(sessionAudioPlayer.play());
    notifyListeners();
  }

  void pauseBackgroundSound() async {
    await backgroundSoundAudioPlayer.pause();
  }

  void pauseSessionAudio() async {
    await sessionAudioPlayer.pause();
    notifyListeners();
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

  void seekValueFromSlider(int duration) {
    sessionAudioPlayer.seek(Duration(milliseconds: duration));
  }

  void skipForward30Secs() {
    var seekDuration = sessionAudioPlayer.position.inMilliseconds +
        Duration(seconds: 30).inMilliseconds;
    sessionAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void skipBackward10Secs() {
    var seekDuration = max(
        0,
        sessionAudioPlayer.position.inMilliseconds -
            Duration(seconds: 10).inMilliseconds);
    sessionAudioPlayer.seek(Duration(milliseconds: seekDuration));
  }

  void setBackgroundSoundVolume(double volume) async {
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }

  void disposeSessionAudio() async {
    await sessionAudioPlayer.dispose();
  }
}
