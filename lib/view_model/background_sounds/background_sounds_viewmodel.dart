import 'dart:async';
import 'dart:convert';

import 'package:Medito/constants/strings/shared_preference_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/services/shared_preference/shared_preferences_service.dart';
import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'background_sounds_viewmodel.g.dart';

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(BackgroundSoundsRef ref) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  return backgroundSoundsRepository.fetchBackgroundSounds();
}

final backgroundSoundsNotifierProvider =
    ChangeNotifierProvider<BackgroundSoundsNotifier>((ref) {
  return BackgroundSoundsNotifier();
});

class BackgroundSoundsNotifier extends ChangeNotifier {
  double volume = 0;
  BackgroundSoundsModel? selectedBgSound;

  void handleOnChangeVolume(double _volume) async {
    volume = _volume;
    unawaited(SharedPreferencesService.addDoubleInSF(
        SharedPreferenceConstants.bgSoundVolume, _volume));
    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel? _sound) async {
    selectedBgSound = _sound;
    unawaited(SharedPreferencesService.addStringInSF(
        SharedPreferenceConstants.bgSound, json.encode(_sound?.toJson())));
    notifyListeners();
  }

  Future<void> getBackgroundSoundFromPref() async {
    await SharedPreferencesService.getStringFromSF(
            SharedPreferenceConstants.bgSound)
        .then((value) {
      if (value != null) {
        selectedBgSound = BackgroundSoundsModel.fromJson(json.decode(value));
        notifyListeners();
      }
    });
  }

  Future<void> getVolumeFromPref() async {
    await SharedPreferencesService.getDoubleFromSF(
            SharedPreferenceConstants.bgSoundVolume)
        .then((value) {
      if (value != null) {
        volume = value;
        notifyListeners();
      } else {
        handleOnChangeVolume(50.0);
      }
    });
  }
}
