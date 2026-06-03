import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/background_sounds/background_sounds_model.dart';
import '../../repositories/background_sounds/background_sounds_repository.dart';
import '../../repositories/downloader/downloader_repository.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/logger.dart';
import '../player/player_provider.dart';

part 'background_sounds_notifier.g.dart';

final _api = MeditoAudioServiceApi();
final iosBackgroundPlayer = AudioPlayer()..setLoopMode(LoopMode.all);

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(Ref ref) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  ref.keepAlive();

  return backgroundSoundsRepository.fetchBackgroundSounds();
}

@riverpod
Future<List<BackgroundSoundsModel>?> fetchLocallySavedBackgroundSounds(
  Ref ref,
) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  ref.watch(backgroundSoundsNotifierProvider);
  ref.keepAlive();

  return backgroundSoundsRepository.fetchLocallySavedBackgroundSounds();
}

class BackgroundSoundsState {
  final double volume;
  final BackgroundSoundsModel? selectedBgSound;
  final BackgroundSoundsModel? downloadingBgSound;

  const BackgroundSoundsState({
    this.volume = 50,
    this.selectedBgSound,
    this.downloadingBgSound,
  });

  BackgroundSoundsState copyWith({
    double? volume,
    Object? selectedBgSound = _sentinel,
    Object? downloadingBgSound = _sentinel,
  }) {
    return BackgroundSoundsState(
      volume: volume ?? this.volume,
      selectedBgSound: selectedBgSound == _sentinel
          ? this.selectedBgSound
          : selectedBgSound as BackgroundSoundsModel?,
      downloadingBgSound: downloadingBgSound == _sentinel
          ? this.downloadingBgSound
          : downloadingBgSound as BackgroundSoundsModel?,
    );
  }
}

const _sentinel = Object();

final backgroundSoundsNotifierProvider =
    NotifierProvider<BackgroundSoundsNotifier, BackgroundSoundsState>(
  () => BackgroundSoundsNotifier(),
);

class BackgroundSoundsNotifier extends Notifier<BackgroundSoundsState> {
  StreamSubscription<Duration>? _fadeSubscription;

  @override
  BackgroundSoundsState build() {
    ref.onDispose(() {
      _fadeSubscription?.cancel();
    });
    return const BackgroundSoundsState();
  }

  void handleOnChangeVolume(double vol) {
    AppLogger.d('BG_SOUND', 'Changing volume to $vol');
    ref.read(backgroundSoundsRepositoryProvider).handleOnChangeVolume(vol);

    var scaledVol = scaledVolume(vol);
    AppLogger.d('BG_SOUND', 'Scaled volume: $scaledVol');

    if (Platform.isAndroid) {
      AppLogger.d('BG_SOUND', 'Setting Android background sound volume');
      _api.setBackgroundSoundVolume(scaledVol);
    } else {
      AppLogger.d('BG_SOUND', 'Setting iOS background sound volume');
      iosBackgroundPlayer.setVolume(scaledVol);
    }

    state = state.copyWith(volume: vol);
  }

  void handleOnChangeSound(BackgroundSoundsModel? sound) {
    AppLogger.d('BG_SOUND', 'Changing sound to: ${sound?.title}');
    state = state.copyWith(selectedBgSound: sound);
    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);

    if (sound != null) {
      bgSoundRepoProvider.saveSelectedBgSoundToSharedPreferences(sound);
      _updateItemsInSavedBgSoundList(sound);

      if (sound.title != 'None') {
        // This will be localized in the UI layer
        var fileName = '${sound.title}.mp3';
        AppLogger.d('BG_SOUND', 'File name: $fileName');
        final downloadAudio = ref.read(downloaderRepositoryProvider);
        downloadAudio.getDownloadedFile(fileName).then((url) {
          if (url == null) {
            AppLogger.d('BG_SOUND', 'File not downloaded, downloading now');
            state = state.copyWith(downloadingBgSound: sound);
            downloadAudio
                .downloadFile(
                  sound.path,
                  fileName: fileName,
                )
                .then((_) {
                  AppLogger.d('BG_SOUND', 'Download completed');
                  state = state.copyWith(downloadingBgSound: null);
                })
                .then((_) => downloadAudio.getDownloadedFile(fileName))
                .then((path) {
                  AppLogger.d('BG_SOUND', 'Downloaded file path: $path');
                  return _play(path);
                });
          } else {
            AppLogger.d('BG_SOUND', 'File already downloaded at: $url');
            _play(url);
          }
        });
      }
    } else {
      AppLogger.d('BG_SOUND', 'Stopping background sound');
      stopBackgroundSound();
    }
  }

  Future<void> _play(String? uri) async {
    if (uri == null) {
      AppLogger.e('BG_SOUND', 'URI is null, cannot play');
      if (Platform.isAndroid) {
        unawaited(_api.stopBackgroundSound());
      } else {
        unawaited(iosBackgroundPlayer.stop());
      }

      return;
    }

    AppLogger.d('BG_SOUND', 'Playing sound with URI: $uri');
    getVolumeFromPref();

    var parsedUri = Uri.parse(uri);
    var isUrl = ['http', 'https'].contains(parsedUri.scheme);
    AppLogger.d('BG_SOUND', 'Is URL: $isUrl');

    if (Platform.isAndroid) {
      try {
        // First clear any existing background sound
        AppLogger.d('BG_SOUND', 'Clearing previous background sound');
        await _api.setBackgroundSound(null);
        await _api.stopBackgroundSound();

        // Set new background sound
        var formattedUri = isUrl ? uri : 'file://$uri';
        AppLogger.d(
            'BG_SOUND', 'Setting Android background sound: $formattedUri');
        await _api.setBackgroundSound(formattedUri);

        // Play the background sound
        AppLogger.d('BG_SOUND', 'Starting background playback');
        await _api.playBackgroundSound();
        
        // Ensure volume is set after playback starts
        _api.setBackgroundSoundVolume(scaledVolume(state.volume));
      } catch (e, s) {
        AppLogger.e('BG_SOUND', 'Error playing Android background sound', e, s);
      }
    } else {
      try {
        if (isUrl) {
          AppLogger.d('BG_SOUND', 'Setting iOS background sound with URL');
          await iosBackgroundPlayer.setUrl(uri);
        } else {
          AppLogger.d(
              'BG_SOUND', 'Setting iOS background sound with file path');
          await iosBackgroundPlayer.setFilePath(uri);
        }
        AppLogger.d('BG_SOUND', 'Playing iOS background sound');
        iosBackgroundPlayer.setVolume(scaledVolume(state.volume));
        unawaited(iosBackgroundPlayer.play());
        _handleFadeAtEndForIos();
      } catch (e, s) {
        AppLogger.e('BG_SOUND', 'Error playing iOS background sound', e, s);
      }
    }
  }

  void togglePlayPause(bool isPlaying) {
    AppLogger.d('BG_SOUND',
        'Toggling background sound play/pause, current isPlaying: $isPlaying');

    if (Platform.isAndroid) {
      if (isPlaying) {
        AppLogger.d('BG_SOUND', 'Pausing Android background sound only');
        _api.pauseBackgroundSound();
      } else {
        AppLogger.d('BG_SOUND', 'Playing Android background sound only');
        _api.playBackgroundSound();
      }
    } else {
      if (isPlaying) {
        AppLogger.d('BG_SOUND', 'Pausing iOS background sound only');
        iosBackgroundPlayer.pause();
      } else {
        AppLogger.d('BG_SOUND', 'Playing iOS background sound only');
        iosBackgroundPlayer.play();
      }
    }
  }

  void stopBackgroundSound() {
    AppLogger.d('BG_SOUND', 'Stopping background sound');
    _fadeSubscription?.cancel();
    _fadeSubscription = null;
    if (Platform.isAndroid) {
      _api.setBackgroundSound(null);
      _api.stopBackgroundSound();
    } else {
      iosBackgroundPlayer.stop();
    }
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
  }

  void getVolumeFromPref() {
    var value =
        ref.read(backgroundSoundsRepositoryProvider).getBgSoundVolume() ?? 50.0;
    handleOnChangeVolume(value);
  }

  void _handleFadeAtEndForIos() {
    _fadeSubscription?.cancel();
    _fadeSubscription = null;

    var durationFromEnd = const Duration(seconds: 10).inMilliseconds;

    _fadeSubscription = iosAudioHandler.positionStream.listen(
      (currentPosition) {
        var duration = iosAudioHandler.duration?.inMilliseconds ?? 0;
        if (duration == 0) {
          iosBackgroundPlayer.setVolume(scaledVolume(state.volume));
          return;
        }

        var remainingTime = duration - currentPosition.inMilliseconds;

        if (remainingTime <= 0) {
          // At or past the end: stay silent. Without this the fade would snap
          // back to full volume on the final position update, causing an
          // audible blip right before playback completes.
          iosBackgroundPlayer.setVolume(0);
        } else if (remainingTime <= durationFromEnd) {
          var newVolume = state.volume * remainingTime / durationFromEnd;
          iosBackgroundPlayer.setVolume(scaledVolume(newVolume));
        } else {
          iosBackgroundPlayer.setVolume(scaledVolume(state.volume));
        }
      },
    );
  }

  double scaledVolume(double vol) {
    var scale = Platform.isIOS ? 0.3 : 0.5;
    return (vol / 100) * scale;
  }
}
