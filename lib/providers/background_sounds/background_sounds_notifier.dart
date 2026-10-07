import '../../services/audio/session_bell_preview.dart';
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

/// Whether [iosBackgroundPlayer] holds an ambient sound to resume with the
/// session. Session bells are separate (IosSessionBells), so this is no
/// longer implied by "bells are off".
bool iosAmbientActive = false;

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(Ref ref) {
  final backgroundSoundsRepository = ref.watch(
    backgroundSoundsRepositoryProvider,
  );
  ref.keepAlive();

  // Offline the request can hang well past the HTTP timeout (token wait +
  // DNS); fail it quickly so the pickers fall back to the cached list.
  return backgroundSoundsRepository.fetchBackgroundSounds().timeout(
    const Duration(seconds: 10),
  );
}

/// What a background sound picker can show without waiting on the network.
class BackgroundSoundCatalog {
  const BackgroundSoundCatalog({
    required this.sounds,
    required this.downloadedIds,
    required this.offline,
    required this.loading,
  });

  /// Ambient sounds only (None and session bells are listed separately).
  final List<BackgroundSoundsModel> sounds;

  /// Sounds whose file is on this device, so they play offline.
  final Set<String> downloadedIds;

  /// The live list could not be fetched: only [downloadedIds] can play.
  final bool offline;

  /// The live list is still being fetched and nothing is cached yet.
  final bool loading;

  bool isAvailable(BackgroundSoundsModel sound) =>
      !offline || downloadedIds.contains(sound.id);
}

/// Ids of the cached sounds whose file has been downloaded (see
/// `_downloadAndPlay`, which stores each one as `<title>.mp3`).
final _downloadedBackgroundSoundIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
      final downloader = ref.watch(downloaderRepositoryProvider);
      final sounds = ref
          .read(backgroundSoundsRepositoryProvider)
          .fetchCachedBackgroundSounds();
      final ids = <String>{};
      for (final sound in sounds) {
        if (await downloader.getDownloadedFile('${sound.title}.mp3') != null) {
          ids.add(sound.id);
        }
      }
      return ids;
    });

/// The live sound list when it loads, otherwise the cached one, with which
/// sounds are playable offline. Lets the pickers render at once instead of a
/// shimmer that never resolves without a connection.
final backgroundSoundCatalogProvider =
    Provider.autoDispose<BackgroundSoundCatalog>((ref) {
      final live = ref.watch(backgroundSoundsProvider);
      final cached = ref
          .read(backgroundSoundsRepositoryProvider)
          .fetchCachedBackgroundSounds();
      final all = live.value ?? cached;
      final ambient = [
        for (final s in all)
          if (s.id != kNoneBackgroundSoundId && s.id != kSessionBellsId) s,
      ];
      final offline = live.hasError && !live.isLoading;
      final downloaded = offline
          ? ref.watch(_downloadedBackgroundSoundIdsProvider).value ??
                const <String>{}
          : const <String>{};
      return BackgroundSoundCatalog(
        sounds: ambient,
        downloadedIds: downloaded,
        offline: offline,
        loading: live.isLoading && ambient.isEmpty,
      );
    });

@riverpod
Future<List<BackgroundSoundsModel>?> fetchLocallySavedBackgroundSounds(
  Ref ref,
) {
  final backgroundSoundsRepository = ref.watch(
    backgroundSoundsRepositoryProvider,
  );
  ref.watch(backgroundSoundsNotifierProvider);
  ref.keepAlive();

  return backgroundSoundsRepository.fetchLocallySavedBackgroundSounds();
}

class BackgroundSoundsState {
  final double volume;
  final BackgroundSoundsModel? selectedBgSound;
  final BackgroundSoundsModel? downloadingBgSound;

  /// Sound that could not be downloaded or played. Drives the retry affordance
  /// on its row — without it a failure is completely silent: the row looks
  /// selected and nothing ever plays.
  final BackgroundSoundsModel? failedBgSound;

  /// Start/middle/end bells. Independent of [selectedBgSound]: bells and an
  /// ambient sound can play together.
  final bool bellsEnabled;

  const BackgroundSoundsState({
    this.volume = 50,
    this.selectedBgSound,
    this.downloadingBgSound,
    this.failedBgSound,
    this.bellsEnabled = false,
  });

  /// Whether anything plays over the session (lights the player's sound
  /// button).
  bool get hasAnySound =>
      bellsEnabled ||
      (selectedBgSound != null &&
          selectedBgSound!.id != kNoneBackgroundSoundId);

  BackgroundSoundsState copyWith({
    bool? bellsEnabled,
    double? volume,
    Object? selectedBgSound = _sentinel,
    Object? downloadingBgSound = _sentinel,
    Object? failedBgSound = _sentinel,
  }) {
    return BackgroundSoundsState(
      bellsEnabled: bellsEnabled ?? this.bellsEnabled,
      volume: volume ?? this.volume,
      selectedBgSound: selectedBgSound == _sentinel
          ? this.selectedBgSound
          : selectedBgSound as BackgroundSoundsModel?,
      downloadingBgSound: downloadingBgSound == _sentinel
          ? this.downloadingBgSound
          : downloadingBgSound as BackgroundSoundsModel?,
      failedBgSound: failedBgSound == _sentinel
          ? this.failedBgSound
          : failedBgSound as BackgroundSoundsModel?,
    );
  }
}

const _sentinel = Object();

const _noneSound = BackgroundSoundsModel(
  id: kNoneBackgroundSoundId,
  title: 'None',
  path: '',
  duration: 0,
);

final backgroundSoundsNotifierProvider =
    NotifierProvider<BackgroundSoundsNotifier, BackgroundSoundsState>(
      () => BackgroundSoundsNotifier(),
    );

class BackgroundSoundsNotifier extends Notifier<BackgroundSoundsState> {
  StreamSubscription<Duration>? _fadeSubscription;

  /// True while a home Timer session owns the player. The ambient sound is
  /// one shared choice; only the bells switch is remembered per scope (on by
  /// default for the Timer, off under tracks).
  bool _timerScope = false;

  void setTimerScope(bool isTimer) => _timerScope = isTimer;

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
    if (!Platform.isAndroid) iosAudioHandler.sessionBells.setVolume(scaledVol);
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

  void handleOnChangeSound(
    BackgroundSoundsModel? sound, {
    bool preview = true,
  }) {
    unawaited(ref.read(sessionBellPreviewProvider).stop());
    AppLogger.d('BG_SOUND', 'Changing sound to: ${sound?.title}');
    // Any new selection clears a previous failure: the retry affordance belongs
    // to the row the user is actually on.
    state = state.copyWith(selectedBgSound: sound, failedBgSound: null);

    if (sound == null) {
      AppLogger.d('BG_SOUND', 'Stopping background sound');
      _stopAmbient();

      return;
    }

    // Bells used to be one of the background sounds; they are a switch now.
    if (sound.id == kSessionBellsId) {
      setSessionBells(true, preview: preview);
      handleOnChangeSound(_noneSound, preview: preview);
      return;
    }

    var bgSoundRepoProvider = ref.read(backgroundSoundsRepositoryProvider);
    bgSoundRepoProvider.saveSelectedBgSoundToSharedPreferences(sound);
    _updateItemsInSavedBgSoundList(sound);

    if (sound.id == kNoneBackgroundSoundId) {
      AppLogger.d('BG_SOUND', 'None selected, stopping background sound');
      _stopAmbient();

      return;
    }

    _stopAmbient();
    unawaited(_downloadAndPlay(sound));
  }

  /// Re-fetches [sound] from scratch after a failure, discarding whatever is
  /// cached for it. Backs the retry affordance on a failed row.
  void retryDownload(BackgroundSoundsModel sound) {
    AppLogger.d('BG_SOUND', 'Retrying download for: ${sound.title}');
    state = state.copyWith(selectedBgSound: sound, failedBgSound: null);
    unawaited(_downloadAndPlay(sound, forceRedownload: true));
  }

  /// Turns the start/middle/end bells on or off, alongside whatever ambient
  /// sound is playing, and remembers it for this scope (tracks or timer).
  /// [preview] rings a bell when switching on, so the user hears it.
  void setSessionBells(bool enabled, {bool preview = true}) {
    ref
        .read(backgroundSoundsRepositoryProvider)
        .saveSessionBellsEnabled(enabled, forTimer: _timerScope);
    state = state.copyWith(bellsEnabled: enabled);
    unawaited(_applySessionBells(enabled, preview: preview));
  }

  Future<void> _applySessionBells(bool enabled, {required bool preview}) async {
    try {
      final volume = scaledVolume(state.volume);
      if (Platform.isAndroid) {
        await _api.setSessionBells(enabled);
      } else if (enabled) {
        await iosAudioHandler.sessionBells.enable(volume);
      } else {
        await iosAudioHandler.sessionBells.disable();
      }
      if (enabled && preview && state.bellsEnabled) {
        await ref.read(sessionBellPreviewProvider).play(volume);
      }
    } catch (error, stack) {
      AppLogger.e('BELLS', 'Failed to switch session bells', error, stack);
    }
  }

  /// Resolves [sound] to a local file — downloading it first if needed — and
  /// plays it.
  ///
  /// Every failure is handled here. The previous `.then` chain had no error
  /// handler, so a failed download became an unhandled async error, which
  /// `PlatformDispatcher.onError` records in Crashlytics as a *fatal* — a
  /// dropped connection showed up as an app crash. It also left
  /// `downloadingBgSound` set, so the tile's spinner never stopped.
  Future<void> _downloadAndPlay(
    BackgroundSoundsModel sound, {
    bool forceRedownload = false,
  }) async {
    var fileName = '${sound.title}.mp3';
    AppLogger.d('BG_SOUND', 'File name: $fileName');
    final downloadAudio = ref.read(downloaderRepositoryProvider);

    try {
      if (forceRedownload) {
        await downloadAudio.deleteDownloadedFile(fileName);
      }

      var played = await _fetchAndPlay(sound, fileName, downloadAudio);

      if (!played) {
        // A file that downloaded but won't play is corrupt — most likely a
        // truncated fragment written by an older build, before downloads
        // became atomic. Those are cached on devices already and no amount of
        // re-selecting the sound would ever get past them, so bin the file and
        // fetch it once more rather than making the user find the retry button.
        AppLogger.d('BG_SOUND', 'Playback failed, re-fetching $fileName');
        await downloadAudio.deleteDownloadedFile(fileName);
        played = await _fetchAndPlay(sound, fileName, downloadAudio);
      }

      state = state.copyWith(failedBgSound: played ? null : sound);
    } catch (e, s) {
      AppLogger.e(
        'BG_SOUND',
        'Failed to prepare background sound ${sound.title}',
        e,
        s,
      );
      state = state.copyWith(failedBgSound: sound);
    } finally {
      if (state.downloadingBgSound?.id == sound.id) {
        state = state.copyWith(downloadingBgSound: null);
      }
    }
  }

  /// Downloads [sound] if it isn't cached and starts playing it. Returns
  /// whether the sound is now playing (a superseded selection counts as
  /// success — nothing failed, the user just moved on).
  Future<bool> _fetchAndPlay(
    BackgroundSoundsModel sound,
    String fileName,
    DownloaderRepository downloadAudio,
  ) async {
    var path = await downloadAudio.getDownloadedFile(fileName);

    if (path == null) {
      AppLogger.d('BG_SOUND', 'File not downloaded, downloading now');
      state = state.copyWith(downloadingBgSound: sound);
      await downloadAudio.downloadFile(sound.path, fileName: fileName);
      AppLogger.d('BG_SOUND', 'Download completed');
      path = await downloadAudio.getDownloadedFile(fileName);
    } else {
      AppLogger.d('BG_SOUND', 'File already downloaded at: $path');
    }

    // The user can pick another sound (or None) while this downloads; don't
    // let a slow download start playing over whatever they chose since.
    if (state.selectedBgSound?.id != sound.id) {
      AppLogger.d('BG_SOUND', 'Selection changed during download, not playing');

      return true;
    }

    return _play(path);
  }

  /// Starts playback of [uri], returning whether it actually started. The
  /// result matters: a cached-but-corrupt file fails here, and the caller uses
  /// that to re-fetch it instead of leaving the user with silence.
  Future<bool> _play(String? uri) async {
    if (uri == null) {
      AppLogger.e('BG_SOUND', 'URI is null, cannot play');
      if (Platform.isAndroid) {
        unawaited(_api.stopBackgroundSound());
      } else {
        unawaited(iosBackgroundPlayer.stop());
      }

      return false;
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
          'BG_SOUND',
          'Setting Android background sound: $formattedUri',
        );
        await _api.setBackgroundSound(formattedUri);

        // Play the background sound
        AppLogger.d('BG_SOUND', 'Starting background playback');
        await _api.playBackgroundSound();

        // Ensure volume is set after playback starts
        _api.setBackgroundSoundVolume(scaledVolume(state.volume));

        return true;
      } catch (e, s) {
        AppLogger.e('BG_SOUND', 'Error playing Android background sound', e, s);

        return false;
      }
    } else {
      try {
        if (isUrl) {
          AppLogger.d('BG_SOUND', 'Setting iOS background sound with URL');
          await iosBackgroundPlayer.setUrl(uri);
        } else {
          AppLogger.d(
            'BG_SOUND',
            'Setting iOS background sound with file path',
          );
          await iosBackgroundPlayer.setFilePath(uri);
        }
        AppLogger.d('BG_SOUND', 'Playing iOS background sound');
        iosBackgroundPlayer.setVolume(scaledVolume(state.volume));
        iosAmbientActive = true;
        unawaited(iosBackgroundPlayer.play());
        _handleFadeAtEndForIos();

        return true;
      } catch (e, s) {
        AppLogger.e('BG_SOUND', 'Error playing iOS background sound', e, s);

        return false;
      }
    }
  }

  void togglePlayPause(bool isPlaying) {
    // Bells follow the primary player in their own controller; this only
    // pauses/resumes an ambient sound, if one is playing.
    if (Platform.isIOS && !iosAmbientActive) return;
    AppLogger.d(
      'BG_SOUND',
      'Toggling background sound play/pause, current isPlaying: $isPlaying',
    );

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

  /// Session over: stops the ambient sound and the bells.
  void stopBackgroundSound() {
    _stopAmbient();
    if (Platform.isAndroid) {
      unawaited(_api.setSessionBells(false));
    } else {
      unawaited(iosAudioHandler.sessionBells.disable());
    }
  }

  /// Stops only the ambient sound (None picked, or switching sounds); the
  /// bells keep their own on/off state.
  void _stopAmbient() {
    unawaited(ref.read(sessionBellPreviewProvider).stop());
    AppLogger.d('BG_SOUND', 'Stopping background sound');
    iosAmbientActive = false;
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
    final repo = ref.read(backgroundSoundsRepositoryProvider);
    final selectedBgSound = repo.getSelectedBgSoundFromSharedPreferences();
    handleOnChangeSound(selectedBgSound, preview: false);
    setSessionBells(
      repo.getSessionBellsEnabled(forTimer: _timerScope),
      preview: false,
    );
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

    _fadeSubscription = iosAudioHandler.positionStream.listen((
      currentPosition,
    ) {
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
    });
  }

  double scaledVolume(double vol) {
    var scale = Platform.isIOS ? 0.3 : 0.5;
    return (vol / 100) * scale;
  }
}
