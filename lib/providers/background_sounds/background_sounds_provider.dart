import 'package:Medito/constants/strings/string_constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:Medito/constants/strings/shared_preference_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'background_sounds_provider.g.dart';

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(BackgroundSoundsRef ref) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);

  return backgroundSoundsRepository.fetchBackgroundSounds();
}

final backgroundSoundsNotifierProvider =
    ChangeNotifierProvider<BackgroundSoundsNotifier>(
  (ref) {
    return BackgroundSoundsNotifier(ref);
  },
);

//ignore:prefer-match-file-name
class BackgroundSoundsNotifier extends ChangeNotifier {
  final Ref ref;
  double volume = 0;
  BackgroundSoundsModel? selectedBgSound;

  BackgroundSoundsNotifier(this.ref);

  void handleOnChangeVolume(double vol) {
    volume = vol;
    unawaited(
      ref.read(sharedPreferencesProvider).setDouble(
            SharedPreferenceConstants.bgSoundVolume,
            vol,
          ),
    );
    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel? sound) {
    selectedBgSound = sound;
    if (sound != null) {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      unawaited(ref.read(sharedPreferencesProvider).setString(
            SharedPreferenceConstants.bgSound,
            json.encode(
              sound.toJson(),
            ),
          ));
      if (sound.title != StringConstants.none) {
        var name = '${sound.title}.mp3';
        downloadAudio.getDownloadedFile(name).then((value) {
          if (value == null) {
            downloadAudio.downloadFile(
              sound.path,
              name: name,
            );
          }
        });
      }
    } else {
      unawaited(
        ref.read(sharedPreferencesProvider).remove(
              SharedPreferenceConstants.bgSound,
            ),
      );
    }
    notifyListeners();
  }

  void getBackgroundSoundFromPref() {
    var value = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.bgSound,
        );
    if (value != null) {
      selectedBgSound = BackgroundSoundsModel.fromJson(json.decode(value));
      notifyListeners();
    }
  }

  void getVolumeFromPref() {
    var value = ref.read(sharedPreferencesProvider).getDouble(
          SharedPreferenceConstants.bgSoundVolume,
        );
    if (value != null) {
      volume = value;
      notifyListeners();
    } else {
      handleOnChangeVolume(50.0);
    }
  }
}
