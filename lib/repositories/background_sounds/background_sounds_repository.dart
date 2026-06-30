import '../../utils/logger.dart';
import 'dart:async';
import 'dart:convert';

import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:medito/models/background_sounds/background_sounds_model.dart';

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
  final HttpApiService client;
  final Ref ref;

  BackgroundSoundsRepositoryImpl({required this.client, required this.ref});

  @override
  Future<List<BackgroundSoundsModel>> fetchBackgroundSounds() async {
    try {
      final response = await client.getRequest(HTTPConstants.backgroundSounds);

      final results = response['results'];
      if (results is! List) {
        throw const ServerError();
      }

      final sounds = [
        const BackgroundSoundsModel(
          id: '0',
          title: 'None', // This will be localized in the UI layer
          duration: 0,
          path: '',
        ),
      ];

      for (final item in results) {
        try {
          if (item is! Map) continue;

          final map = Map<String, dynamic>.fromEntries(
            item.entries.map((e) => MapEntry(e.key.toString(), e.value)),
          );

          final sound = BackgroundSoundsModel.fromJson(map);
          sounds.add(sound);
        } catch (e) {
          AppLogger.e('BACKGROUND', 'Error parsing background sound: $e');
          // Skip invalid items instead of failing the whole request
          continue;
        }
      }

      return sounds;
    } catch (e) {
      AppLogger.e('BACKGROUND', 'Error fetching background sounds: $e');
      if (e is AppError) rethrow;
      throw const ServerError();
    }
  }

  @override
  Future<List<BackgroundSoundsModel>?>
  fetchLocallySavedBackgroundSounds() async {
    try {
      var pref = ref.read(sharedPreferencesProvider);
      var soundList =
          pref.getStringList(SharedPreferenceConstants.listBgSound) ?? [];
      if (soundList.isNotEmpty) {
        var sounds = <BackgroundSoundsModel>[];
        for (var element in soundList) {
          sounds.add(BackgroundSoundsModel.fromJson(json.decode(element)));
        }

        return sounds;
      }
    } catch (err) {
      AppLogger.d('BACKGROUND', err.toString());
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
        var soundList =
            pref.getStringList(SharedPreferenceConstants.listBgSound) ?? [];
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
      AppLogger.d('BACKGROUND', err.toString());
    }
  }

  @override
  void saveSelectedBgSoundToSharedPreferences(BackgroundSoundsModel sound) {
    var bgSoundJson = json.encode(sound.toJson());
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(SharedPreferenceConstants.bgSound, bgSoundJson),
    );
  }

  @override
  BackgroundSoundsModel? getSelectedBgSoundFromSharedPreferences() {
    var bgSoundJson = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.bgSound);

    return bgSoundJson != null
        ? BackgroundSoundsModel.fromJson(json.decode(bgSoundJson))
        : null;
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
BackgroundSoundsRepository backgroundSoundsRepository(Ref ref) {
  return BackgroundSoundsRepositoryImpl(client: HttpApiService(), ref: ref);
}
