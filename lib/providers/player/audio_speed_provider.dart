import 'dart:async';
import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioSpeedProvider = ChangeNotifierProvider<AudioSpeedProvider>((ref) {
  return AudioSpeedProvider(ref);
});

class AudioSpeedProvider extends ChangeNotifier {
  final Ref ref;
  final List<String> _speedList = [
    StringConstants.x06,
    StringConstants.x07,
    StringConstants.x08,
    StringConstants.x09,
    StringConstants.x1,
    StringConstants.x125,
    StringConstants.x15,
  ];
  AudioSpeedModel audioSpeedModel = AudioSpeedModel();

  AudioSpeedProvider(this.ref);

  void setAudioTrackSpeed() {
    double speed;
    String label;
    var nextIndex = _speedList.indexOf(audioSpeedModel.label) + 1;
    label =
        nextIndex >= _speedList.length ? _speedList[0] : _speedList[nextIndex];
    if (label == StringConstants.x06) {
      speed = 0.6;
    } else if (label == StringConstants.x07) {
      speed = 0.7;
    } else if (label == StringConstants.x08) {
      speed = 0.8;
    } else if (label == StringConstants.x09) {
      speed = 0.9;
    } else if (label == StringConstants.x1) {
      speed = 1;
    } else if (label == StringConstants.x125) {
      speed = 1.25;
    } else if (label == StringConstants.x15) {
      speed = 1.5;
    } else {
      speed = 1;
    }
    audioSpeedModel = AudioSpeedModel(label: label, speed: speed);
    unawaited(
      ref.read(sharedPreferencesProvider).setString(
            SharedPreferenceConstants.sessionAudioSpeed,
            json.encode(
              audioSpeedModel.toJson(),
            ),
          ),
    );
    notifyListeners();
  }

  void getAudioTrackSpeedFromPref() {
    var audioSpeedFromPref = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.sessionAudioSpeed,
        );
    if (audioSpeedFromPref != null) {
      audioSpeedModel =
          AudioSpeedModel.fromJson(json.decode(audioSpeedFromPref));
      notifyListeners();
    }
  }
}
