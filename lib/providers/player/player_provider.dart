import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/models.dart';

import '../../constants/strings/shared_preference_constants.dart';
import '../../models/player/repeat_mode.dart' as app_repeat;
import '../../src/audio_pigeon.g.dart' as pigeon;
import '../../utils/utils.dart';
import '../shared_preference/shared_preference_provider.dart';
import 'download/audio_downloader_provider.dart';
import 'ios_audio_handler.dart';
import '../../utils/logger.dart';

final _api = pigeon.MeditoAudioServiceApi();
final _androidServiceApi = pigeon.MeditoAndroidAudioServiceManager();
late IosAudioHandler iosAudioHandler;

final playerProvider =
    NotifierProvider<PlayerProvider, PlaybackRequest?>(() {
  return PlayerProvider();
});

class PlayerProvider extends Notifier<PlaybackRequest?> {
  @override
  PlaybackRequest? build() => null;

  /// Starts (or restarts) playback for [request]. The provider's state holds
  /// the same [PlaybackRequest] for the lifetime of the session so the player
  /// UI never has to inspect a nested track graph to know what is playing.
  ///
  /// Throws on failure to start playback (e.g. native audio service didn't
  /// start, ExoPlayer threw, iOS audio session couldn't be configured).
  /// Callers MUST wrap in try/catch and surface the failure to the user —
  /// otherwise we end up navigating to a player screen with no audio (silent
  /// failure that looks like a broken app).
  Future<void> play(PlaybackRequest request) async {
    AppLogger.d('PLAYER',
        'Loading track: ${request.title}, fileId: ${request.fileId}');

    await _playTrack(request);
    state = request;
  }

  /// Warm-prepares the state without actually starting playback. Used for
  /// preloading next-up tracks so the player screen has data immediately when
  /// the user taps play.
  void prepare(PlaybackRequest request) {
    if (state?.trackId == request.trackId) return;
    state = request;
  }

  Future<void> _playTrack(PlaybackRequest request) async {
    AppLogger.d('PLAYER',
        '_playTrack called for track: ${request.trackId}, file: ${request.fileId}');

    final downloadPath = await ref
        .read(audioDownloaderProvider.notifier)
        .getTrackPath(_constructFileName(request));

    final url = downloadPath ?? request.remoteUrl;
    AppLogger.d('PLAYER', 'Will use path: $url');

    final trackData = pigeon.Track(
      id: request.trackId,
      title: request.title,
      fileId: request.fileId,
      artist: request.guideName ?? '',
      artistUrl: request.artist?.path,
      description: request.description,
      imageUrl: request.coverUrl,
    );

    if (Platform.isAndroid) {
      AppLogger.d(
          'PLAYER', 'On Android - starting service and checking readiness');
      // NOTE: errors here intentionally propagate to play() and onwards to the
      // caller. Previously this was a swallow ('catch (e) { log; }') which
      // resolved play() successfully despite playback never starting, leading
      // to a silent-fail player screen. See P0-4 in the audit.
      await _androidServiceApi.startService();
      AppLogger.d('PLAYER',
          'Service start requested, now waiting briefly before checking readiness');
      await Future.delayed(const Duration(milliseconds: 500));

      final isReady = await _waitForServiceReadiness();

      if (isReady) {
        AppLogger.d('PLAYER', 'Service is ready, proceeding with playback');
      } else {
        AppLogger.w('PLAYER',
            'Service failed to become ready, attempting playback anyway');
        await Future.delayed(const Duration(seconds: 1));
      }
      await _playAudioWithRetry(url, trackData);
    } else {
      AppLogger.d('PLAYER', 'On iOS - setting up audio');
      // NOTE: errors here intentionally propagate (see comment above for the
      // Android path). _playAudioWithRetry on Android already rethrows after
      // its retry budget — iOS has no such retry layer, so a single failure
      // here propagates immediately. That's intentional: callers need to know.
      await iosAudioHandler.setUrl(downloadPath, request, trackData);
      AppLogger.d('PLAYER', 'iOS setUrl succeeded');
      await iosAudioHandler.play();
      AppLogger.d('PLAYER', 'iOS play() called');
    }
  }

  Future<bool> _waitForServiceReadiness() async {
    const maxAttempts = 10;
    const initialDelayMs = 500;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        AppLogger.d('PLAYER',
            'Checking if service is ready (attempt ${attempt + 1})');
        final isReady = await _androidServiceApi.isServiceReady();
        AppLogger.d('PLAYER',
            'Service readiness check returned: $isReady (attempt ${attempt + 1})');

        if (isReady) {
          AppLogger.d('PLAYER', 'Service is ready');
          return true;
        } else {
          AppLogger.d('PLAYER', 'Service not ready yet, waiting...');
          final delayMs = initialDelayMs * (1 << attempt);
          await Future.delayed(Duration(milliseconds: delayMs));
        }
      } catch (e) {
        AppLogger.e('PLAYER',
            'Error during service readiness check (attempt ${attempt + 1})', e);
        final delayMs = initialDelayMs * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    AppLogger.e('PLAYER', 'Service readiness check timed out');
    return false;
  }

  Future<void> _playAudioWithRetry(String url, pigeon.Track trackData) async {
    const maxAttempts = 3;
    const initialDelayMs = 300;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        AppLogger.d('PLAYER',
            'Calling playAudio with url: $url (attempt ${attempt + 1})');

        await _api.playAudio(
          pigeon.AudioData(
            url: url,
            track: trackData,
          ),
        );

        AppLogger.d('PLAYER', 'playAudio call succeeded');
        return;
      } catch (e) {
        AppLogger.e(
            'PLAYER', 'Error playing audio (attempt ${attempt + 1}): $e');

        if (attempt < maxAttempts - 1) {
          final delayMs = initialDelayMs * (1 << attempt);
          AppLogger.d('PLAYER', 'Retrying playAudio in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
        } else {
          rethrow;
        }
      }
    }
  }

  String? getUserToken() {
    return ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferenceConstants.userToken);
  }

  String _constructFileName(PlaybackRequest request) =>
      '${request.trackId}-${request.fileId}${getAudioFileExtension(request.remoteUrl)}';

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
      app_repeat.RepeatMode.none => pigeon.RepeatMode.none,
      app_repeat.RepeatMode.once => pigeon.RepeatMode.once,
      app_repeat.RepeatMode.infinite => pigeon.RepeatMode.infinite,
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
}

const audioPercentageListened = 0.8;
const androidNotificationIcon = 'logo';
const notificationId = 1595122;
const androidNotificationChannelId = 'medito_reminder_channel';
