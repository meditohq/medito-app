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

  void setBackgroundAudio(BackgroundSoundsModel sound) async {
    unawaited(backgroundSoundAudioPlayer.setUrl(sound.path, headers: {
      HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
    }));
  }

  void playBackgroundSound() async {
    unawaited(backgroundSoundAudioPlayer.play());
  }

  void pauseBackgroundSound() async {
    await backgroundSoundAudioPlayer.pause();
  }

  void stopBackgroundSound() async {
    await backgroundSoundAudioPlayer.stop();
  }

  void setBackgroundSoundVolume(double volume) async {
    await backgroundSoundAudioPlayer.setVolume(volume / 100);
  }
}
