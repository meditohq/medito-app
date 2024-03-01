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
    TrackModel track,
    TrackFilesModel file,
  ) async {
    await _startBackgroundThreadForAudioCompleteEvent(
      track.id,
      file.duration,
    );

    var downloadPath = await ref.read(audioDownloaderProvider).getTrackPath(
          _constructFileName(track, file),
        );
    await _api.playAudio(
      AudioData(
        url: downloadPath ?? file.path,
        track: Track(
          title: track.title,
          artist: track.artist?.name ?? '',
          artistUrl: track.artist?.path ?? '',
          description: track.description,
          imageUrl: track.coverUrl,
        ),
      ),
    );
  }

  Future<void> _startBackgroundThreadForAudioCompleteEvent(
    String trackId,
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
      initialDelay: Duration(milliseconds: duration * audioPercentageListened as int),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      inputData: {
        TypeConstants.trackIdKey: trackId,
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
    String guide,
    String trackId,
    String audioFileId,
    int duration,
  ) {
    var audio = AudioStartedModel(
      fileId: audioFileId,
      fileDuration: duration,
      fileGuide: guide,
    );
    ref.read(audioStartedEventProvider(event: audio.toJson(), trackId: trackId));
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

  void handleAudioCompletionEvent(
    String trackId,
  ) {
    ref.read(markAsListenedEventProvider(id: trackId));
  }
}

const audioPercentageListened = 0.7;