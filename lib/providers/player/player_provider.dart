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
    var track = trackModel.customCopyWith();
    var audios = [...track.audio];

    audios.forEach((audioModel) {
      var fileIndex = audioModel.files.indexWhere((it) => it.id == file.id);
      if (fileIndex != -1) {
        track.audio.removeWhere((e) => e.guideName != audioModel.guideName);
        track.audio.first.files
            .removeWhere((e) => e.id != audioModel.files[fileIndex].id);

        return;
      }
    });

    final audioPlayerNotifier = ref.read(audioPlayerNotifierProvider);

    state = track;
    _optionallyLoadBackgroundSound(
      ref,
      audioPlayerNotifier,
      track,
      track.audio.first.files.first,
    );
    await _playTrack(
      ref,
      audioPlayerNotifier,
      track,
      file,
    );
  }

  void _optionallyLoadBackgroundSound(
    Ref ref,
    AudioPlayerNotifier audioPlayerNotifier,
    TrackModel trackModel,
    TrackFilesModel file,
  ) {
    var isPlaying = audioPlayerNotifier.trackAudioPlayer.playerState.playing;
    var currentPlayingFileId = audioPlayerNotifier.currentlyPlayingTrack?.id;

    if (!isPlaying || currentPlayingFileId != file.id) {
      _optionallyPlayBackgroundSound(
        ref,
        audioPlayerNotifier,
        trackModel.hasBackgroundSound,
      );
    }
  }

  Future<void> _playTrack(
    Ref ref,
    AudioPlayerNotifier audioPlayerNotifier,
    TrackModel trackModel,
    TrackFilesModel file,
  ) async {
    var checkDownloadedFile = ref.read(audioDownloaderProvider).getTrackAudio(
          _constructFileName(trackModel, file),
        );
    var filePath = await checkDownloadedFile;
    audioPlayerNotifier.setTrackAudio(
      trackModel,
      file,
      filePath: filePath,
    );
    audioPlayerNotifier.currentlyPlayingTrack = file;
    unawaited(audioPlayerNotifier.play());
  }

  String _constructFileName(TrackModel trackModel, TrackFilesModel file) =>
      '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

  void _optionallyPlayBackgroundSound(
    Ref ref,
    AudioPlayerNotifier audioPlayerNotifier,
    bool hasBackgroundSound,
  ) {
    if (hasBackgroundSound) {
      final _provider = ref.read(backgroundSoundsNotifierProvider);
      _provider.getBackgroundSoundFromPref();
      if (_provider.selectedBgSound != null &&
          _provider.selectedBgSound?.title != StringConstants.none) {
        audioPlayerNotifier.setBackgroundAudio(_provider.selectedBgSound!);
        audioPlayerNotifier.playBackgroundSound();
      }

      _provider.getVolumeFromPref();
      audioPlayerNotifier.setBackgroundSoundVolume(_provider.volume);
    } else {
      audioPlayerNotifier.pauseBackgroundSound();
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
