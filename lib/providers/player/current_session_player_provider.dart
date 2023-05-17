import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentSessionPlayerProvider = Provider<void>((ref) {
  final currentlyPlayingSession = ref.watch(playerProvider);
  if (currentlyPlayingSession != null) {
    _loadSessionAndBackgroundSound(
      ref,
      currentlyPlayingSession,
      currentlyPlayingSession.audio.first.files.first,
    );
  }
});

void _loadSessionAndBackgroundSound(
  Ref ref,
  SessionModel sessionModel,
  SessionFilesModel file,
) {
  final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
  var isPlaying = _audioPlayerNotifier.sessionAudioPlayer.playerState.playing;
  var _currentPlayingFileId = _audioPlayerNotifier.currentlyPlayingSession?.id;

  if (!isPlaying || _currentPlayingFileId != file.id) {
    _setBackgroundSound(
      ref,
      _audioPlayerNotifier,
      sessionModel.hasBackgroundSound,
    );
    _setSessionAudio(ref, _audioPlayerNotifier, sessionModel, file);
  }
}

void _setSessionAudio(
  Ref ref,
  AudioPlayerNotifier _audioPlayerNotifier,
  SessionModel sessionModel,
  SessionFilesModel file,
) {
  var checkDownloadedFile = ref.read(audioDownloaderProvider).getSessionAudio(
        '${sessionModel.id}-${file.id}${getFileExtension(file.path)}',
      );
  checkDownloadedFile.then((value) {
    _audioPlayerNotifier.setSessionAudio(sessionModel, file, filePath: value);
    _audioPlayerNotifier.currentlyPlayingSession = file;
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
