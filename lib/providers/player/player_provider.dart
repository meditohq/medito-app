import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/models/models.dart';
import 'package:Medito/utils/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../constants/strings/shared_preference_constants.dart';
import '../../constants/types/type_constants.dart';
import '../../services/notifications/notifications_service.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/call_update_stats.dart';
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
    if (Platform.isAndroid) {
      await _startNotificationForAudioCompleteEvent(
        track.id,
        file.duration,
        file.id,
        DateTime.now().millisecondsSinceEpoch,
        guideName,
      );
    }

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
      await Future.delayed(Duration(milliseconds: 500));

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

  Future<void> _startNotificationForAudioCompleteEvent(
    String trackId,
    int duration,
    String fileID,
    int timestamp,
    String fileGuide,
  ) async {
    await requestNotificationPermissions();

    var payload = {
      TypeConstants.trackIdKey: trackId,
      TypeConstants.durationIdKey: duration,
      TypeConstants.fileIdKey: fileID,
      TypeConstants.guideIdKey: fileGuide,
      TypeConstants.timestampIdKey: timestamp,
      UpdateStatsConstants.userTokenKey: getUserToken(),
    };
    var notificationDelay = (duration * audioPercentageListened).round();
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        notificationTitle,
        notificationBody,
        payload: json.encode(payload),
        tz.TZDateTime.now(tz.local)
            .add(Duration(milliseconds: notificationDelay)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            androidNotificationChannelId,
            androidNotificationChannelName,
            playSound: false,
            icon: androidNotificationIcon,
            enableVibration: false,
            channelDescription: androidNotificationChannelDescription,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, s) {
      print(s);
    }
  }

  String? getUserToken() {
    var user = ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.userToken);
    var userModel =
        user != null ? UserTokenModel.fromJson(json.decode(user)) : null;
    if (userModel != null) {
      return userModel.token;
    }

    return null;
  }

  void cancelBackgroundThreadForAudioCompleteEvent() async {
    var activeNotifications =
        await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    var containsNotification = activeNotifications
        .any((notification) => notification.id == notificationId);

    if (!containsNotification) {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
    }
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
      iosAudioHandler.seek(iosAudioHandler.position + Duration(seconds: 10));
    }
  }

  void skip10SecondsBackward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsBackward();
    } else {
      iosAudioHandler.seek(iosAudioHandler.position - Duration(seconds: 10));
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

  void handleAudioCompletionEvent(
    String trackId,
  ) {
    ref.read(markAsListenedEventProvider(id: trackId));
  }
}

const audioPercentageListened = 0.8;
const androidNotificationIcon = 'logo';
