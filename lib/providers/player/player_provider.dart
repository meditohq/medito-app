import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';
import 'package:flutter/foundation.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../models/player/repeat_mode.dart' as app_repeat;
import '../../src/audio_pigeon.g.dart';
import '../../utils/utils.dart';
import '../shared_preference/shared_preference_provider.dart';
import 'download/audio_downloader_provider.dart';
import 'ios_audio_handler.dart';
import '../../utils/logger.dart';

final _api = MeditoAudioServiceApi();
final _androidServiceApi = MeditoAndroidAudioServiceManager();
late IosAudioHandler iosAudioHandler;

final playerProvider =
    NotifierProvider<PlayerProvider, TrackModel?>(() {
  return PlayerProvider();
});

class PlayerProvider extends Notifier<TrackModel?> {

  @override
  TrackModel? build() => null;

  Future<void> loadSelectedTrack({
    required TrackModel trackModel,
    required TrackFilesModel file,
  }) async {
    AppLogger.d('PLAYER',
        '🔊 Loading track: \\${trackModel.title}, fileId: \\${file.id}');
    var track = trackModel.customCopyWith();
    var audios = [...track.audio];

    for (var audioModel in audios) {
      var fileIndex = audioModel.files.indexWhere((it) => it.id == file.id);
      if (fileIndex != -1) {
        track.audio.removeWhere((e) => e.guideName != audioModel.guideName);
        track.audio.first.files
            .removeWhere((e) => e.id != audioModel.files[fileIndex].id);
      }
    }

    AppLogger.d('PLAYER',
        '🔊 Selected track: \\${track.title}, audio count: \\${track.audio.length}');

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
    debugPrint(
        '🔊 _playTrack called for track: \\${track.id}, file: \\${file.id}');
    var downloadPath = await ref.read(audioDownloaderProvider.notifier).getTrackPath(
          _constructFileName(track, file),
        );

    debugPrint(
        '🔊 Download path: \\${downloadPath ?? 'null'}, file path: \\${file.path}');
    AppLogger.d('PLAYER', '🔊 Will use path: \\${downloadPath ?? file.path}');

    var imageUrl = track.coverUrl;

    var trackData = Track(
      id: track.id,
      title: track.title,
      fileId: file.id,
      artist: track.audio.first.guideName ?? '',
      artistUrl: track.artist?.path,
      description: track.description,
      imageUrl: imageUrl,
    );

    if (Platform.isAndroid) {
      AppLogger.d(
          'PLAYER', '🔊 On Android - starting service and checking readiness');
      try {
        // Start service and wait for readiness
        await _androidServiceApi.startService();
        debugPrint(
            '🔊 Service start requested, now waiting briefly before checking readiness');
        // Add a small delay to allow the service to initialize
        await Future.delayed(const Duration(milliseconds: 500));

        // Wait for service to be ready with timeout
        final isReady = await _waitForServiceReadiness();

        if (isReady) {
          AppLogger.d(
              'PLAYER', '🔊 Service is ready, proceeding with playback');
          await _playAudioWithRetry(downloadPath ?? file.path, trackData);
        } else {
          debugPrint(
              '❌ Service failed to become ready, attempting playback anyway');
          // Proceed with playback attempt even if service readiness times out
          await Future.delayed(const Duration(seconds: 1));
          await _playAudioWithRetry(downloadPath ?? file.path, trackData);
        }
      } catch (e) {
        debugPrint(
            '❌ Fatal error starting service or playing audio: \\${e.toString()}');
      }
    } else {
      AppLogger.d('PLAYER', '🔊 On iOS - setting up audio');
      try {
        await iosAudioHandler.setUrl(downloadPath, file, trackData);
        AppLogger.d('PLAYER', '🔊 iOS setUrl succeeded');
        await iosAudioHandler.play();
        AppLogger.d('PLAYER', '🔊 iOS play() called');
      } catch (e) {
        AppLogger.e(
            'PLAYER', '❌ Error playing audio on iOS: \\${e.toString()}');
      }
    }
  }

  // Wait for the service to become ready with timeout
  Future<bool> _waitForServiceReadiness() async {
    const maxAttempts = 10;
    const initialDelayMs = 500;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        AppLogger.d('PLAYER',
            '🔊 Checking if service is ready (attempt ${attempt + 1})');
        final isReady = await _androidServiceApi.isServiceReady();
        debugPrint(
            '🔊 Service readiness check returned: $isReady (attempt ${attempt + 1})');

        if (isReady) {
          AppLogger.d('PLAYER', '🔊 Service is ready');
          return true;
        } else {
          AppLogger.d('PLAYER', '🔊 Service not ready yet, waiting...');
          final delayMs = initialDelayMs * (1 << attempt);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      } catch (e) {
        debugPrint(
            '❌ Error during service readiness check (attempt ${attempt + 1}): $e');
        final delayMs = initialDelayMs * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    AppLogger.e('PLAYER', '❌ Service readiness check timed out');
    return false;
  }

  // Retry playing audio with exponential backoff
  Future<void> _playAudioWithRetry(String url, Track trackData) async {
    const maxAttempts = 3;
    const initialDelayMs = 300;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        debugPrint(
            '🔊 Calling playAudio with url: $url (attempt ${attempt + 1})');

        await _api.playAudio(
          AudioData(
            url: url,
            track: trackData,
          ),
        );

        AppLogger.d('PLAYER', '🔊 playAudio call succeeded');
        return; // Success
      } catch (e) {
        AppLogger.e(
            'PLAYER', '❌ Error playing audio (attempt ${attempt + 1}): $e');

        if (attempt < maxAttempts - 1) {
          // Calculate backoff delay
          final delayMs = initialDelayMs * (1 << attempt);
          AppLogger.d('PLAYER', '🔊 Retrying playAudio in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          rethrow; // Rethrow on final attempt
        }
      }
    }
  }

  String? getUserToken() {
    return ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.userToken);
  }

  String _constructFileName(TrackModel trackModel, TrackFilesModel file) =>
      '${trackModel.id}-${file.id}${getAudioFileExtension(file.path)}';

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

  void setRepeatMode(app_repeat.RepeatMode mode) {
    final pigeonMode = switch (mode) {
      app_repeat.RepeatMode.none => RepeatMode.none,
      app_repeat.RepeatMode.once => RepeatMode.once,
      app_repeat.RepeatMode.infinite => RepeatMode.infinite,
    };
    if (Platform.isAndroid) {
      _api.setRepeatMode(pigeonMode);
    } else {
      iosAudioHandler.setCustomRepeatMode(pigeonMode);
    }
  }

  void skip10SecondsForward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsForward();
    } else {
      iosAudioHandler.seek(
        iosAudioHandler.position + const Duration(seconds: 15),
      );
    }
  }

  void skip10SecondsBackward() {
    if (Platform.isAndroid) {
      _api.skip10SecondsBackward();
    } else {
      iosAudioHandler.seek(
        iosAudioHandler.position - const Duration(seconds: 15),
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

  void cacheTrackData(
      {required TrackModel track, required TrackFilesModel file}) {
    if (state?.id == track.id) return;
    state = track.customCopyWith()..audio = [track.audio.first];
  }
}

const audioPercentageListened = 0.8;
const androidNotificationIcon = 'logo';
const notificationId = 1595122;
const androidNotificationChannelId = 'medito_reminder_channel';
