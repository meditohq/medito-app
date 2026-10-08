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

  /// The sound list as last fetched online, or the sounds this device has
  /// picked before if it has never been fetched. Never touches the network.
  List<BackgroundSoundsModel> fetchCachedBackgroundSounds();

  Future<void> updateItemsInSavedBgSoundList(BackgroundSoundsModel sound);

  /// The ambient sound, one choice shared by tracks and the Timer.
  void saveSelectedBgSoundToSharedPreferences(BackgroundSoundsModel sound);

  /// The ambient sound (never session bells, which are a separate switch).
  BackgroundSoundsModel? getSelectedBgSoundFromSharedPreferences();

  /// Bells default on for the Timer and off under tracks, except for users
  /// who had picked bells as their background sound before they were a switch.
  bool getSessionBellsEnabled({bool forTimer = false});

  void saveSessionBellsEnabled(bool enabled, {bool forTimer = false});

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
          id: kNoneBackgroundSoundId,
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

      _cacheCatalog(sounds);
      return sounds;
    } catch (e) {
      AppLogger.e('BACKGROUND', 'Error fetching background sounds: $e');
      if (e is AppError) rethrow;
      throw const ServerError();
    }
  }

  void _cacheCatalog(List<BackgroundSoundsModel> sounds) {
    final encoded = jsonEncode([
      for (final s in sounds)
        if (s.id != kNoneBackgroundSoundId) s.toJson(),
    ]);
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(SharedPreferenceConstants.bgSoundCatalog, encoded),
    );
  }

  @override
  List<BackgroundSoundsModel> fetchCachedBackgroundSounds() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final catalog = prefs.getString(SharedPreferenceConstants.bgSoundCatalog);
      if (catalog != null) {
        return [
          for (final item in jsonDecode(catalog) as List)
            BackgroundSoundsModel.fromJson(Map<String, Object?>.from(item)),
        ];
      }
      return [
        for (final item
            in prefs.getStringList(SharedPreferenceConstants.listBgSound) ??
                const <String>[])
          BackgroundSoundsModel.fromJson(jsonDecode(item)),
      ];
    } catch (e) {
      AppLogger.w('BACKGROUND', 'Unreadable cached sound list: $e');
      return const [];
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
      if (sound.id == kNoneBackgroundSoundId || sound.id == kSessionBellsId) {
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

    if (bgSoundJson == null) return null;
    final sound = BackgroundSoundsModel.fromJson(json.decode(bgSoundJson));
    // Saved before bells became a switch: the bells live in their own pref.
    return sound.id == kSessionBellsId ? null : sound;
  }

  @override
  bool getSessionBellsEnabled({bool forTimer = false}) {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getBool(
      forTimer
          ? SharedPreferenceConstants.timerSessionBellsEnabled
          : SharedPreferenceConstants.sessionBellsEnabled,
    );
    if (saved != null) return saved;
    if (forTimer) return true;
    final legacy = prefs.getString(SharedPreferenceConstants.bgSound);
    return legacy != null && legacy.contains('"$kSessionBellsId"');
  }

  @override
  void saveSessionBellsEnabled(bool enabled, {bool forTimer = false}) {
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setBool(
            forTimer
                ? SharedPreferenceConstants.timerSessionBellsEnabled
                : SharedPreferenceConstants.sessionBellsEnabled,
            enabled,
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
BackgroundSoundsRepository backgroundSoundsRepository(Ref ref) {
  return BackgroundSoundsRepositoryImpl(client: HttpApiService(), ref: ref);
}
