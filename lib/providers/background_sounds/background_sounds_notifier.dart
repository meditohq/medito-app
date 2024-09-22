import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/strings/string_constants.dart';
import '../../models/background_sounds/background_sounds_model.dart';
import '../../repositories/background_sounds/background_sounds_repository.dart';
import '../../repositories/downloader/downloader_repository.dart';
import '../../src/audio_pigeon.g.dart';
import '../player/player_provider.dart';

part 'background_sounds_notifier.g.dart';

final _api = MeditoAudioServiceApi();
final iosBackgroundPlayer = AudioPlayer()..setLoopMode(LoopMode.all);

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

class BackgroundSoundsNotifier extends ChangeNotifier {
  final Ref ref;
  double volume = 50;
  BackgroundSoundsModel? selectedBgSound;
  BackgroundSoundsModel? downloadingBgSound;

  BackgroundSoundsNotifier(this.ref);

  void handleOnChangeVolume(double vol) {
    ref.read(backgroundSoundsRepositoryProvider).handleOnChangeVolume(vol);
    volume = vol;

    var scaledVol = scaledVolume(vol);

    if (Platform.isAndroid) {
      _api.setBackgroundSoundVolume(scaledVol);
    } else {
      iosBackgroundPlayer.setVolume(scaledVol);
    }

    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel? sound) {
    selectedBgSound = sound;
    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);

    if (sound != null) {
      bgSoundRepoProvider.saveSelectedBgSoundToSharedPreferences(sound);
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

  Future<void> _play(String? uri) async {
    if (uri == null) {
      if (Platform.isAndroid) {
        unawaited(_api.stopBackgroundSound());
      } else {
        unawaited(iosBackgroundPlayer.stop());
      }

      return;
    }

    getVolumeFromPref();

    var parsedUri = Uri.parse(uri);
    var isUrl = ['http', 'https'].contains(parsedUri.scheme);

    if (Platform.isAndroid) {
      if (isUrl) {
        await _api.setBackgroundSound(uri);
      } else {
        await _api.setBackgroundSound('file://$uri');
      }
      unawaited(_api.playBackgroundSound());
    } else {
      try {
        if (isUrl) {
          await iosBackgroundPlayer.setUrl(uri);
        } else {
          await iosBackgroundPlayer.setFilePath(uri);
        }
      } catch (e, s) {
        print(s);
      }
      unawaited(iosBackgroundPlayer.play());
      _handleFadeAtEndForIos();
    }
  }

  void togglePlayPause(isPlaying) {
    if (Platform.isAndroid) {
      if (isPlaying) {
        _api.pauseBackgroundSound();
      } else {
        _api.playBackgroundSound();
      }
    } else {
      if (isPlaying) {
        iosBackgroundPlayer.pause();
      } else {
        iosBackgroundPlayer.play();
      }
    }
    notifyListeners();
  }

  void stopBackgroundSound() {
    if (Platform.isAndroid) {
      _api.setBackgroundSound(null);
      _api.stopBackgroundSound();
    } else {
      iosBackgroundPlayer.stop();
    }
    notifyListeners();
  }

  void _updateItemsInSavedBgSoundList(BackgroundSoundsModel sound) {
    final provider = ref.read(backgroundSoundsRepositoryProvider);
    provider.updateItemsInSavedBgSoundList(sound);
  }

  void playBackgroundSoundFromPref() {
    var selectedBgSound = ref
        .read(backgroundSoundsRepositoryProvider)
        .getSelectedBgSoundFromSharedPreferences();
    handleOnChangeSound(selectedBgSound);
    notifyListeners();
  }

  void getVolumeFromPref() {
    var value =
        ref.read(backgroundSoundsRepositoryProvider).getBgSoundVolume() ?? 50.0;
    handleOnChangeVolume(value);
    volume = value;
  }

  void _handleFadeAtEndForIos() {
    var durationFromEnd = const Duration(seconds: 10).inMilliseconds;

    iosAudioHandler.positionStream.listen(
      (currentPosition) {
        var duration = iosAudioHandler.duration?.inMilliseconds ?? 0;
        var remainingTime = duration - currentPosition.inMilliseconds;

        if (remainingTime <= durationFromEnd) {
          var newVolume = volume * remainingTime / durationFromEnd;
          iosBackgroundPlayer.setVolume(scaledVolume(newVolume));
        } else {
          iosBackgroundPlayer.setVolume(scaledVolume(volume));
        }
      },
    );
  }

  double scaledVolume(double vol) {
    var scale = Platform.isIOS ? 0.3 : 0.5;
    return (vol / 100) * scale;
  }
}
