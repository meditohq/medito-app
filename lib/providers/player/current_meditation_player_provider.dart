import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentMeditationPlayerProvider = Provider<void>((ref) {
  final currentlyPlayingMeditation = ref.watch(playerProvider);
  if (currentlyPlayingMeditation != null) {
    _loadMeditationAndBackgroundSound(
      ref,
      currentlyPlayingMeditation,
      currentlyPlayingMeditation.audio.first.files.first,
    );
  }
});

void _loadMeditationAndBackgroundSound(
  Ref ref,
  MeditationModel meditationModel,
  MeditationFilesModel file,
) {
  final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
  var isPlaying = _audioPlayerNotifier.meditationAudioPlayer.playerState.playing;
  var _currentPlayingFileId = _audioPlayerNotifier.currentlyPlayingMeditation?.id;

  if (!isPlaying || _currentPlayingFileId != file.id) {
    _setBackgroundSound(
      ref,
      _audioPlayerNotifier,
      meditationModel.hasBackgroundSound,
    );
    _setMeditationAudio(ref, _audioPlayerNotifier, meditationModel, file);
  }
}

void _setMeditationAudio(
  Ref ref,
  AudioPlayerNotifier _audioPlayerNotifier,
  MeditationModel meditationModel,
  MeditationFilesModel file,
) {
  var checkDownloadedFile = ref.read(audioDownloaderProvider).getMeditationAudio(
        '${meditationModel.id}-${file.id}${getFileExtension(file.path)}',
      );
  checkDownloadedFile.then((value) {
    _audioPlayerNotifier.setMeditationAudio(meditationModel, file, filePath: value);
    _audioPlayerNotifier.currentlyPlayingMeditation = file;
    ref.read(audioPlayPauseStateProvider.notifier).state =
        PLAY_PAUSE_AUDIO.PLAY;
  });
}

void _setBackgroundSound(
  Ref ref,
  AudioPlayerNotifier _audioPlayerNotifier,
  bool hasBackgroundSound,
) {
  if (hasBackgroundSound) {
    final _provider = ref.read(backgroundSoundsNotifierProvider);
    _provider.getBackgroundSoundFromPref().then((_) {
      if (_provider.selectedBgSound != null &&
          _provider.selectedBgSound?.title != StringConstants.none) {
        _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);

        _audioPlayerNotifier.playBackgroundSound();
      }
    });
    _provider.getVolumeFromPref().then((_) {
      _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
    });
  } else {
    _audioPlayerNotifier.pauseBackgroundSound();
  }
}
