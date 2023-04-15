import 'dart:async';
import 'dart:convert';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioSpeedProvider = ChangeNotifierProvider<AudioSpeedProvider>((ref) {
  return AudioSpeedProvider();
});

class AudioSpeedProvider extends ChangeNotifier {
  final List<String> _speedList = [
    StringConstants.X1,
    StringConstants.X125,
    StringConstants.X15,
    StringConstants.X2,
    StringConstants.X06,
  ];
  AudioSpeedModel audioSpeedModel = AudioSpeedModel();

  void setAudioTrackSpeed() {
    double speed;
    String label;
    var nextIndex = _speedList.indexOf(audioSpeedModel.label) + 1;
    label =
        nextIndex >= _speedList.length ? _speedList[0] : _speedList[nextIndex];
    if (label == StringConstants.X1) {
      speed = 1;
    } else if (label == StringConstants.X125) {
      speed = 1.25;
    } else if (label == StringConstants.X15) {
      speed = 1.5;
    } else if (label == StringConstants.X2) {
      speed = 2;
    } else if (label == StringConstants.X06) {
      speed = 0.6;
    } else {
      speed = 1;
    }
    audioSpeedModel = AudioSpeedModel(label: label, speed: speed);
    unawaited(
      SharedPreferencesService.addStringInSharedPref(
        SharedPreferenceConstants.sessionAudioSpeed,
        json.encode(
          audioSpeedModel.toJson(),
        ),
      ),
    );
    notifyListeners();
  }

  Future<void> getAudioTrackSpeedFromPref() async {
    var audioSpeedFromPref =
        await SharedPreferencesService.getStringFromSharedPref(
      SharedPreferenceConstants.sessionAudioSpeed,
    );
    if (audioSpeedFromPref != null) {
      audioSpeedModel =
          AudioSpeedModel.fromJson(json.decode(audioSpeedFromPref));
      notifyListeners();
    }
  }
}
