import 'dart:async';
import 'dart:convert';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'background_sounds_repository.g.dart';

abstract class BackgroundSoundsRepository {
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds();

  Future<List<BackgroundSoundsModel>?> fetchLocallySavedBackgroundSounds();

  Future<void> updateItemsInSavedBgSoundList(BackgroundSoundsModel sound);

  void handleOnChangeSound(BackgroundSoundsModel sound);

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
    var response = await client.getRequest(HTTPConstants.BACKGROUND_SOUNDS);
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
        var _sounds = <BackgroundSoundsModel>[];
        for (var element in soundList) {
          _sounds.add(BackgroundSoundsModel.fromJson(json.decode(element)));
        }

        return _sounds;
      }
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        stackTrace: err,
      ));
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
        var _sounds = <BackgroundSoundsModel>[];
        for (var element in soundList) {
          _sounds.add(BackgroundSoundsModel.fromJson(json.decode(element)));
        }
        var index = _sounds.indexWhere((element) => element.id == sound.id);
        if (index == -1) {
          _sounds.add(sound);
          var encodeSounds = _sounds.map((e) => json.encode(e)).toList();
          await pref.setStringList(
            SharedPreferenceConstants.listBgSound,
            encodeSounds,
          );
        }
      }
    } catch (err) {
      unawaited(Sentry.captureException(
        err,
        stackTrace: err,
      ));
    }
  }

  @override
  void handleOnChangeSound(BackgroundSoundsModel sound) {
    unawaited(
      ref.read(sharedPreferencesProvider).setString(
            SharedPreferenceConstants.bgSound,
            json.encode(
              sound.toJson(),
            ),
          ),
    );
  }

  @override
  void removeSelectedBgSound() {
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .remove(SharedPreferenceConstants.bgSound),
    );
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
    client: ref.watch(dioClientProvider),
    ref: ref,
  );
}
