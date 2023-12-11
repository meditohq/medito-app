import 'dart:async';
import 'dart:convert';

import 'package:Medito/constants/strings/shared_preference_constants.dart';
import 'package:Medito/constants/strings/string_constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_sounds_provider.g.dart';

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(BackgroundSoundsRef ref) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  ref.keepAlive();

  return backgroundSoundsRepository.fetchBackgroundSounds();
}

@riverpod
Future<List<BackgroundSoundsModel>?> fetchLocallySavedBackgroundSounds(
  FetchLocallySavedBackgroundSoundsRef ref,
) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  ref.watch(backgroundSoundsNotifierProvider);
  ref.keepAlive();

  return backgroundSoundsRepository.fetchLocallySavedBackgroundSounds();
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
    ref.read(backgroundSoundsRepositoryProvider).handleOnChangeVolume(vol);
    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel? sound) {
    selectedBgSound = sound;
    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);
    if (sound != null) {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      bgSoundRepoProvider.handleOnChangeSound(sound);
      updateItemsInSavedBgSoundList(sound);
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
      bgSoundRepoProvider.removeSelectedBgSound();
    }
    notifyListeners();
  }

  void updateItemsInSavedBgSoundList(BackgroundSoundsModel sound) {
    final provider = ref.read(backgroundSoundsRepositoryProvider);
    provider.updateItemsInSavedBgSoundList(sound);
  }

  void getBackgroundSoundFromPref() {
    var value = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.bgSound);
    if (value != null) {
      selectedBgSound = BackgroundSoundsModel.fromJson(json.decode(value));
      notifyListeners();
    }
  }

  void getVolumeFromPref() {
    var value = ref.read(backgroundSoundsRepositoryProvider).getBgSoundVolume();
    if (value != null) {
      volume = value;
      notifyListeners();
    } else {
      handleOnChangeVolume(50.0);
    }
  }
}
