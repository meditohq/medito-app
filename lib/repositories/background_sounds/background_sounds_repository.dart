import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/dio_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'background_sounds_repository.g.dart';

abstract class BackgroundSoundsRepository {
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds();

  Future<List<BackgroundSoundsModel>?> fetchLocallySavedBackgroundSounds();

  Future<void> updateItemsInSavedBgSoundList(BackgroundSoundsModel sound);

  void saveSelectedBgSoundToSharedPreferences(BackgroundSoundsModel sound);

  BackgroundSoundsModel? getSelectedBgSoundFromSharedPreferences();

  void removeSelectedBgSound();

  void handleOnChangeVolume(double vol);

  double? getBgSoundVolume();
}

class BackgroundSoundsRepositoryImpl extends BackgroundSoundsRepository {
  final DioApiService client;
  final Ref ref;

  BackgroundSoundsRepositoryImpl({required this.client, required this.ref});

  @override
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds() async {
    var response = await client.getRequest(HTTPConstants.backgroundSounds);
    var tempResponse = response as List;
    var bgSoundList = <BackgroundSoundsModel>[];
    const noneBgSound = BackgroundSoundsModel(
      id: '0',
      title: StringConstants.none,
      duration: 0,
      path: '',
    );
    bgSoundList.add(noneBgSound);
    var parsedResponseList =
        tempResponse.map((x) => BackgroundSoundsModel.fromJson(x)).toList();

    bgSoundList.addAll(parsedResponseList);

    return bgSoundList;
  }

  @override
  Future<List<BackgroundSoundsModel>?>
      fetchLocallySavedBackgroundSounds() async {
    try {
      var pref = ref.read(sharedPreferencesProvider);
      var soundList = pref.getStringList(
            SharedPreferenceConstants.listBgSound,
          ) ??
          [];
      if (soundList.isNotEmpty) {
        var sounds = <BackgroundSoundsModel>[];
        for (var element in soundList) {
          sounds.add(BackgroundSoundsModel.fromJson(json.decode(element)));
        }

        return sounds;
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }

    return null;
  }

  @override
  Future<void> updateItemsInSavedBgSoundList(
    BackgroundSoundsModel sound,
  ) async {
    try {
      if (sound.id == '0') {
        return;
      } else {
        var pref = ref.read(sharedPreferencesProvider);
        var soundList = pref.getStringList(
              SharedPreferenceConstants.listBgSound,
            ) ??
            [];
        var sounds = <BackgroundSoundsModel>[];
        for (var element in soundList) {
          sounds.add(BackgroundSoundsModel.fromJson(json.decode(element)));
        }
        var index = sounds.indexWhere((element) => element.id == sound.id);
        if (index == -1) {
          sounds.add(sound);
          var encodeSounds = sounds.map((e) => json.encode(e)).toList();
          await pref.setStringList(
            SharedPreferenceConstants.listBgSound,
            encodeSounds,
          );
        }
      }
    } catch (err) {
      if (kDebugMode) {
        print(err);
      }
    }
  }

  @override
  void saveSelectedBgSoundToSharedPreferences(BackgroundSoundsModel sound) {
    var bgSoundJson = json.encode(sound.toJson());
    unawaited(
      ref.read(sharedPreferencesProvider).setString(
            SharedPreferenceConstants.bgSound,
            bgSoundJson,
          ),
    );
  }

  @override
  BackgroundSoundsModel? getSelectedBgSoundFromSharedPreferences() {
    var bgSoundJson = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.bgSound,
        );

    return bgSoundJson != null
        ? BackgroundSoundsModel.fromJson(json.decode(bgSoundJson))
        : null;
  }

  @override
  void removeSelectedBgSound() {
    unawaited(ref
        .read(sharedPreferencesProvider)
        .remove(SharedPreferenceConstants.bgSound));
  }

  @override
  double? getBgSoundVolume() {
    return ref
        .read(sharedPreferencesProvider)
        .getDouble(SharedPreferenceConstants.bgSoundVolume);
  }

  @override
  void handleOnChangeVolume(double vol) {
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setDouble(SharedPreferenceConstants.bgSoundVolume, vol),
    );
  }
}

@riverpod
BackgroundSoundsRepositoryImpl backgroundSoundsRepository(
  BackgroundSoundsRepositoryRef ref,
) {
  return BackgroundSoundsRepositoryImpl(
    client: DioApiService(),
    ref: ref,
  );
}
