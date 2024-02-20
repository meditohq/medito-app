import 'dart:async';
import 'dart:convert';

import 'package:Medito/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/utils.dart';
import '../../utils/workmanager.dart';
import '../../utils/workmanager_constants.dart';
import '../events/events_provider.dart';
import '../shared_preference/shared_preference_provider.dart';
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
    await _startBackgroundThreadForAudioCompleteEvent(
      file.id,
      trackModel.id,
      file.duration,
    );

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

  Future<void> _startBackgroundThreadForAudioCompleteEvent(
    String fileId,
    String trackModelId,
    int duration,
  ) async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    await Workmanager().registerOneOffTask(
      audioCompletedTaskKey,
      audioCompletedTaskKey,
      backoffPolicy: BackoffPolicy.linear,
      initialDelay: Duration(milliseconds: duration),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      inputData: {
        TypeConstants.fileIdKey: fileId,
        TypeConstants.trackIdKey: trackModelId,
        WorkManagerConstants.userTokenKey: getUserToken(),
      },
    );
  }

  String? getUserToken() {
    var user = ref.read(sharedPreferencesProvider).getString(
          SharedPreferenceConstants.userToken,
        );
    var userModel =
        user != null ? UserTokenModel.fromJson(json.decode(user)) : null;
    if (userModel != null) {
      return userModel.token;
    }

    return null;
  }

  void cancelBackgroundThreadForAudioCompleteEvent() async {
    await Workmanager().cancelAll();
  }

  String _constructFileName(TrackModel trackModel, TrackFilesModel file) =>
      '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

  void handleAudioStartedEvent(
    String trackId,
    String audioFileId,
    int duration,
  ) {
    var audio = AudioStartedModel(
      audioFileId: audioFileId,
      trackId: trackId,
      duration: duration,
    );
    var event = EventsModel(
      name: EventTypes.audioStarted,
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
