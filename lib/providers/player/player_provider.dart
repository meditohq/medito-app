import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/providers/player/audio_state_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
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
final _androidServiceApi = MeditoAndroidAudioServiceManager();
final iosPlayer = AudioPlayer();

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
      track.audio.first.guideName ?? '',
    );

    state = track;
  }

  Future<void> _playTrack(
    Ref ref,
    TrackModel track,
    TrackFilesModel file,
    String guideName,
  ) async {
    // await _startBackgroundThreadForAudioCompleteEvent(
    //   track.id,
    //   file.duration,
    //   file.id,
    //   DateTime
    //       .now()
    //       .millisecondsSinceEpoch,
    //   guideName,
    // );

    var downloadPath = await ref.read(audioDownloaderProvider).getTrackPath(
          _constructFileName(track, file),
        );

    var trackData = Track(
      title: track.title,
      artist: track.artist?.name ?? '',
      artistUrl: track.artist?.path ?? '',
      description: track.description,
      imageUrl: track.coverUrl,
    );

    if (Platform.isAndroid) {
      await _androidServiceApi.startService();
      // wait half a sec for the service to start
      await Future.delayed(Duration(milliseconds: 500));

      await _api.playAudio(
        AudioData(
          url: downloadPath ?? file.path,
          track: trackData,
        ),
      );
    } else {
      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration.speech());

        if (downloadPath == null) {
          await iosPlayer.setAudioSource(
            AudioSource.uri(
              Uri.parse(
                file.path,
              ),
            ),
          );
        } else {
          await iosPlayer.setAsset(
            downloadPath,
          );
        }

        trackStateSubject.add(trackData);
        unawaited(iosPlayer.play());
      } catch (e) {
        print(e);
      }
    }
  }

  Future<void> _startBackgroundThreadForAudioCompleteEvent(
    String trackId,
    int duration,
    String fileID,
    int timestamp,
    String fileGuide,
  ) async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );

    try {
      await Workmanager().registerOneOffTask(
        audioCompletedTaskKey,
        audioCompletedTaskKey,
        backoffPolicy: BackoffPolicy.linear,
        initialDelay: Duration(
          milliseconds: (duration * audioPercentageListened).round(),
        ),
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: {
          TypeConstants.trackIdKey: trackId,
          TypeConstants.durationIdKey: duration,
          TypeConstants.fileIdKey: fileID,
          TypeConstants.guideIdKey: fileGuide,
          TypeConstants.timestampIdKey: timestamp,
          WorkManagerConstants.userTokenKey: getUserToken(),
        },
      );
    } catch (e, s) {
      if (kDebugMode) {
        print(s);
      }
    }
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
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    ref.read(
      audioStartedEventProvider(
        event: audio.toJson(),
        trackId: trackId,
      ),
    );
  }

  Future<void> seekToPosition(int position) async {
    if (Platform.isAndroid) {
      await _api.seekToPosition(position);
    } else {
      await iosPlayer.seek(Duration(milliseconds: position));
    }
  }

  void stop() {
    if (Platform.isAndroid) {
      _api.stopAudio();
    } else {
      iosPlayer.stop();
    }
  }

  void setSpeed(double speed) {
    if (Platform.isAndroid) {
      _api.setSpeed(speed);
    } else {
      iosPlayer.setSpeed(speed);
    }
  }

  void skip10SecondsForward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsForward();
    } else {
      iosPlayer.seek(iosPlayer.position + Duration(seconds: 10));
    }
  }

  void skip10SecondsBackward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsBackward();
    } else {
      iosPlayer.seek(iosPlayer.position - Duration(seconds: 10));
    }
  }

  void playPause() {
    if (Platform.isAndroid) {
      _api.playPauseAudio();
    } else {
      if (iosPlayer.playing) {
        iosPlayer.pause();
      } else {
        iosPlayer.play();
      }
    }
  }

  void handleAudioCompletionEvent(
    String trackId,
  ) {
    ref.read(markAsListenedEventProvider(id: trackId));
  }
}

const audioPercentageListened = 0.7;
