import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider =
    StateNotifierProvider<PlayerProvider, TrackModel?>((ref) {
  return PlayerProvider(ref);
});

class PlayerProvider extends StateNotifier<TrackModel?> {
  PlayerProvider(this.ref) : super(null);
  Ref ref;
  Future<void> loadSelectedTrack({
    required TrackModel trackModel,
    required TrackFilesModel file,
  }) async {
    var _track = trackModel.customCopyWith();
    for (var i = 0; i < _track.audio.length; i++) {
      var element = _track.audio[i];
      var fileIndex = element.files.indexWhere((e) => e.id == file.id);
      if (fileIndex != -1) {
        _track.audio.removeWhere((e) => e.guideName != element.guideName);
        _track.audio.first.files
            .removeWhere((e) => e.id != element.files[fileIndex].id);
        break;
      }
    }

    state = _track;
    await _loadTrackAndBackgroundSound(
      ref,
      _track,
      _track.audio.first.files.first,
    );
  }

  Future<void> _loadTrackAndBackgroundSound(
    Ref ref,
    TrackModel trackModel,
    TrackFilesModel file, {
    bool isPlayAudio = true,
  }) async {
    final _audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);
    var isPlaying = _audioPlayerNotifier.trackAudioPlayer.playerState.playing;
    var _currentPlayingFileId = _audioPlayerNotifier.currentlyPlayingTrack?.id;

    if (!isPlaying || _currentPlayingFileId != file.id) {
      _setBackgroundSound(
        ref,
        _audioPlayerNotifier,
        trackModel.hasBackgroundSound,
        isPlayAudio: isPlayAudio,
      );
      await _setTrackAudio(
        ref,
        _audioPlayerNotifier,
        trackModel,
        file,
        isPlayAudio: isPlayAudio,
      );
    }
  }

  Future<void> _setTrackAudio(
    Ref ref,
    AudioPlayerNotifier _audioPlayerNotifier,
    TrackModel trackModel,
    TrackFilesModel file, {
    bool isPlayAudio = true,
  }) async {
    var checkDownloadedFile = ref.read(audioDownloaderProvider).getTrackAudio(
          '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}',
        );
    var res = await checkDownloadedFile;
    _audioPlayerNotifier.setTrackAudio(
      trackModel,
      file,
      filePath: res,
    );
    _audioPlayerNotifier.currentlyPlayingTrack = file;
    if (isPlayAudio) {
      unawaited(_audioPlayerNotifier.play());
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
      _provider.getBackgroundSoundFromPref();
      if (_provider.selectedBgSound != null &&
          _provider.selectedBgSound?.title != StringConstants.none) {
        _audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        if (isPlayAudio) {
          _audioPlayerNotifier.playBackgroundSound();
        }
      }

      _provider.getVolumeFromPref();
      _audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
    } else {
      _audioPlayerNotifier.pauseBackgroundSound();
    }
  }

  void handleAudioStartedEvent(
    String trackId,
    String audioFileId,
  ) {
    var audio = AudioStartedModel(audioFileId: audioFileId, trackId: trackId);
    var event = EventsModel(
      name: EventTypes.audioStarted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  void handleAudioCompletionEvent(
    String audioFileId,
    String trackId,
  ) {
    var audio = AudioCompletedModel(
      audioFileId: audioFileId,
      trackId: trackId,
      updateStats: true,
    );
    var event = EventsModel(
      name: EventTypes.audioCompleted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
