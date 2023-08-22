import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider =
    StateNotifierProvider<PlayerProvider, MeditationModel?>((ref) {
  return PlayerProvider(ref);
});

class PlayerProvider extends StateNotifier<MeditationModel?> {
  PlayerProvider(this.ref) : super(null);
  Ref ref;
  Future<void> addCurrentlyPlayingMeditationInPreference({
    required MeditationModel meditationModel,
    required MeditationFilesModel file,
  }) async {
    var _meditation = meditationModel.customCopyWith();
    for (var i = 0; i < _meditation.audio.length; i++) {
      var element = _meditation.audio[i];
      var fileIndex = element.files.indexWhere((e) => e.id == file.id);
      if (fileIndex != -1) {
        _meditation.audio.removeWhere((e) => e.guideName != element.guideName);
        _meditation.audio.first.files
            .removeWhere((e) => e.id != element.files[fileIndex].id);
        break;
      }
    }

    state = _meditation;
    await ref
        .read(meditationRepositoryProvider)
        .addCurrentlyPlayingMeditationInPreference(_meditation);

    await _loadMeditationAndBackgroundSound(
      ref,
      _meditation,
      _meditation.audio.first.files.first,
    );
  }

  Future<void> getCurrentlyPlayingMeditation({bool isPlayAudio = true}) async {
    var res = await ref
        .read(meditationRepositoryProvider)
        .fetchCurrentlyPlayingMeditationFromPreference();
    state = res;
    if (res != null) {
      await _loadMeditationAndBackgroundSound(
        ref,
        res,
        res.audio.first.files.first,
        isPlayAudio: isPlayAudio,
      );
    }
  }

  Future<void> _loadMeditationAndBackgroundSound(
    Ref ref,
    MeditationModel meditationModel,
    MeditationFilesModel file, {
    bool isPlayAudio = true,
  }) async {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    var isPlaying =
        _audioPlayerNotifier.meditationAudioPlayer.playerState.playing;
    var _currentPlayingFileId =
        _audioPlayerNotifier.currentlyPlayingMeditation?.id;

    if (!isPlaying || _currentPlayingFileId != file.id) {
      _setBackgroundSound(
        ref,
        _audioPlayerNotifier,
        meditationModel.hasBackgroundSound,
        isPlayAudio: isPlayAudio,
      );
      await _setMeditationAudio(
        ref,
        _audioPlayerNotifier,
        meditationModel,
        file,
        isPlayAudio: isPlayAudio,
      );
    }
  }

  Future<void> _setMeditationAudio(
    Ref ref,
    AudioPlayerNotifier _audioPlayerNotifier,
    MeditationModel meditationModel,
    MeditationFilesModel file, {
    bool isPlayAudio = true,
  }) async {
    var checkDownloadedFile =
        ref.read(audioDownloaderProvider).getMeditationAudio(
              '${meditationModel.id}-${file.id}${getFileExtension(file.path)}',
            );
    var res = await checkDownloadedFile;
    _audioPlayerNotifier.setMeditationAudio(
      meditationModel,
      file,
      filePath: res,
    );
    _audioPlayerNotifier.currentlyPlayingMeditation = file;
    if (isPlayAudio) {
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PLAY;
    }
  }

  void _setBackgroundSound(
    Ref ref,
    AudioPlayerNotifier _audioPlayerNotifier,
    bool hasBackgroundSound, {
    bool isPlayAudio = true,
  }) {
    if (hasBackgroundSound) {
      final _provider = ref.read(backgroundSoundsNotifierProvider);
      _provider.getBackgroundSoundFromPref().then((_) {
        if (_provider.selectedBgSound != null &&
            _provider.selectedBgSound?.title != StringConstants.none) {
          _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
          if (isPlayAudio) {
            _audioPlayerNotifier.playBackgroundSound();
          }
        }
      });
      _provider.getVolumeFromPref().then((_) {
        _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
      });
    } else {
      _audioPlayerNotifier.pauseBackgroundSound();
    }
  }
}
