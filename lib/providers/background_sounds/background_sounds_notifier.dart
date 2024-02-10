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

import '../../src/audio_pigeon.g.dart';

part 'background_sounds_notifier.g.dart';

final _api = MeditoAudioServiceApi();

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
  double volume = 50;
  BackgroundSoundsModel? selectedBgSound;
  BackgroundSoundsModel? downloadingBgSound;

  BackgroundSoundsNotifier(this.ref);

  void handleOnChangeVolume(double vol) {
    volume = vol;
    ref.read(backgroundSoundsRepositoryProvider).handleOnChangeVolume(vol);
    _api.setBackgroundSoundVolume(volume);
    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel? sound) {
    selectedBgSound = sound;
    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);

    if (sound != null) {
      bgSoundRepoProvider.saveBgSoundToSharedPreferences(sound);
      _updateItemsInSavedBgSoundList(sound);

      if (sound.title != StringConstants.none) {
        var name = '${sound.title}.mp3';
        final downloadAudio = ref.read(downloaderRepositoryProvider);
        downloadAudio.getDownloadedFile(name).then((url) {
          if (url == null) {
            downloadingBgSound = sound;
            notifyListeners();
            downloadAudio
                .downloadFile(
                  sound.path,
                  name: name,
                )
                .then((_) => downloadingBgSound = null)
                .then((_) => _play(selectedBgSound?.path))
                .then((_) => notifyListeners());
          } else {
            _play(url);
          }
        });
      }
    } else {
      stopBackgroundSound();
    }
    notifyListeners();
  }

  void _play(String? value) {
    _api.setBackgroundSound(value);
    _api.playBackgroundSound();
  }

  void stopBackgroundSound() {
    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);
    bgSoundRepoProvider.removeSelectedBgSound();
    _api.setBackgroundSound(null);
    _api.stopBackgroundSound();
    notifyListeners();
  }

  void _updateItemsInSavedBgSoundList(BackgroundSoundsModel sound) {
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
    var value =
        ref.read(backgroundSoundsRepositoryProvider).getBgSoundVolume() ?? 50.0;
    handleOnChangeVolume(value);
    volume = value;
  }
}
