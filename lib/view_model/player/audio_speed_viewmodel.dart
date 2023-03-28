import 'dart:async';
import 'dart:convert';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioSpeedProvider = ChangeNotifierProvider<AudioSpeedViewModel>((ref) {
  return AudioSpeedViewModel();
});

class AudioSpeedViewModel extends ChangeNotifier {
  final List<String> _speedList = ['X1', 'X1.25', 'X1.5', 'X2', 'X0.6'];
  AudioSpeedModel audioSpeedModel = AudioSpeedModel();

  void setAudioTrackSpeed() {
    double speed;
    String label;
    var nextIndex = _speedList.indexOf(audioSpeedModel.label) + 1;
    if (nextIndex >= _speedList.length) {
      label = _speedList[0];
    } else {
      label = _speedList[nextIndex];
    }
    if (label == 'X1') {
      speed = 1;
    } else if (label == 'X1.25') {
      speed = 1.25;
    } else if (label == 'X1.5') {
      speed = 1.5;
    } else if (label == 'X2') {
      speed = 2;
    } else if (label == 'X0.6') {
      speed = 0.6;
    } else if (label == 'X0.75') {
      speed = 1;
    } else {
      speed = 0.75;
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
    var audioSpeedFromPref = await SharedPreferencesService.getStringFromSharedPref(
        SharedPreferenceConstants.sessionAudioSpeed);
    if (audioSpeedFromPref != null) {
      audioSpeedModel =
          AudioSpeedModel.fromJson(json.decode(audioSpeedFromPref));
      notifyListeners();
    }
  }
}
