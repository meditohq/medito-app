import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/utils.dart';
import '../events/events_provider.dart';
import '../shared_preference/shared_preference_provider.dart';
import 'download/audio_downloader_provider.dart';
import 'ios_audio_handler.dart';

final _api = MeditoAudioServiceApi();
final _androidServiceApi = MeditoAndroidAudioServiceManager();
final iosAudioHandler = IosAudioHandler();

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

    ref.read(playerProvider.notifier).handleAudioStartedEvent(
          track.audio
                  .where((e) => e.files.any((f) => f.duration == file.duration))
                  .first
                  .guideName ??
              '-',
          track.id,
          file.id,
          file.duration,
        );

    for (var audioModel in audios) {
      var fileIndex = audioModel.files.indexWhere((it) => it.id == file.id);
      if (fileIndex != -1) {
        track.audio.removeWhere((e) => e.guideName != audioModel.guideName);
        track.audio.first.files
            .removeWhere((e) => e.id != audioModel.files[fileIndex].id);
      }
    }

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
    var downloadPath = await ref.read(audioDownloaderProvider).getTrackPath(
          _constructFileName(track, file),
        );

    var trackData = Track(
      id: track.id,
      title: track.title,
      artist: track.audio.first.guideName,
      artistUrl: track.artist?.path ?? '',
      description: track.description,
      imageUrl: track.coverUrl,
    );

    if (Platform.isAndroid) {
      await _androidServiceApi.startService();
      // wait half a sec for the service to start
      await Future.delayed(const Duration(milliseconds: 500));

      await _api.playAudio(
        AudioData(
          url: downloadPath ?? file.path,
          track: trackData,
        ),
      );
    } else {
      await iosAudioHandler.setUrl(downloadPath, file, trackData);
      await iosAudioHandler.play();
    }
  }

  String? getUserToken() {
    return ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.userToken);
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
        event: audio.toJson().map(
              (key, value) => MapEntry(key, value.toString()),
            ),
        trackId: trackId,
      ),
    );
  }

  Future<void> seekToPosition(int position) async {
    if (Platform.isAndroid) {
      await _api.seekToPosition(position);
    } else {
      await iosAudioHandler.seek(Duration(milliseconds: position));
    }
  }

  void stop() {
    if (Platform.isAndroid) {
      _api.stopAudio();
    } else {
      iosAudioHandler.stop();
    }
  }

  void setSpeed(double speed) {
    if (Platform.isAndroid) {
      _api.setSpeed(speed);
    } else {
      iosAudioHandler.setSpeed(speed);
    }
  }

  void skip10SecondsForward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsForward();
    } else {
      iosAudioHandler.seek(
        iosAudioHandler.position + const Duration(seconds: 10),
      );
    }
  }

  void skip10SecondsBackward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsBackward();
    } else {
      iosAudioHandler.seek(
        iosAudioHandler.position - const Duration(seconds: 10),
      );
    }
  }

  void playPause() {
    if (Platform.isAndroid) {
      _api.playPauseAudio();
    } else {
      if (iosAudioHandler.playing) {
        iosAudioHandler.pause();
      } else {
        iosAudioHandler.play();
      }
    }
  }
}

const audioPercentageListened = 0.8;
const androidNotificationIcon = 'logo';
const notificationId = 1595122;
const androidNotificationChannelId = 'medito_reminder_channel';
