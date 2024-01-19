import 'dart:async';

import 'package:Medito/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../constants/strings/string_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/utils.dart';
import '../background_sounds/background_sounds_notifier.dart';
import '../events/events_provider.dart';
import 'download/audio_downloader_provider.dart';

final _api = MeditoAudioServiceApi();

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

    await _playTrack(
      ref,
      track,
      file,
    );

    state = track;
  }

  Future<void> _playTrack(
    Ref ref,
    TrackModel trackModel,
    TrackFilesModel file,
  ) async {
    var downloadPath = await ref.read(audioDownloaderProvider).getTrackPath(
          _constructFileName(trackModel, file),
        );
    await _api.playAudio(
      AudioData(
        url: downloadPath ?? file.path,
        track: Track(
          title: trackModel.title,
          artist: trackModel.artist?.name ?? '',
          artistUrl: trackModel.artist?.path ?? '',
          description: trackModel.description,
          imageUrl: trackModel.coverUrl,
        ),
      ),
    );
  }

  String _constructFileName(TrackModel trackModel, TrackFilesModel file) =>
      '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

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

  Future<void> seekToPosition(int position) async {
    await _api.seekToPosition(position);
  }

  void stop() {
    _api.stopAudio();
  }

  void setSpeed(double speed) {
    _api.setSpeed(speed);
  }

  void skip10SecondsForward() {
    _api.skip10SecondsForward();
  }

  void skip10SecondsBackward() {
    _api.skip10SecondsBackward();
  }

  void playPause() {
    _api.playPauseAudio();
  }
}
