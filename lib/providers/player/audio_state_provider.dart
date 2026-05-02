import 'dart:io';

import 'package:medito/providers/player/player_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../constants/types/type_constants.dart';
import '../../services/analytics/crashlytics_service.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/stats_updater.dart';

class AudioStateProvider implements MeditoAudioServiceCallbackApi {
  final AudioStateNotifier notifier;
  final WidgetRef? ref;

  AudioStateProvider(this.notifier, {this.ref});

  @override
  void updatePlaybackState(PlaybackState state) {
    notifier.updatePlaybackState(state);
  }

  @override
  void reportPlayerError(
    String errorCode,
    String message,
    int positionMs,
    int durationMs,
  ) {
    CrashlyticsService().recordError(
      Exception('ExoPlayer $errorCode: $message'),
      StackTrace.current,
      reason: 'ExoPlayer onPlayerError',
      information: [
        'errorCode=$errorCode',
        'positionMs=$positionMs',
        'durationMs=$durationMs',
      ],
    );
  }

  // only used on Android
  @override
  Future<bool> handleCompletedTrack(CompletionData completionData) async {
    try {
      await handleStats({
        TypeConstants.trackIdKey: completionData.trackId,
        TypeConstants.durationIdKey: completionData.duration,
        TypeConstants.fileIdKey: completionData.fileId,
        TypeConstants.guideIdKey: completionData.guideId,
        TypeConstants.timestampIdKey: completionData.timestamp,
      });

      return true;
    } on Exception catch (_) {
      return false;
    }
  }
}

class AudioStateNotifier extends Notifier<PlaybackState> {
  @override
  PlaybackState build() {
    final initialState = PlaybackState(
      position: 0,
      isPlaying: false,
      isBuffering: false,
      isSeeking: false,
      isCompleted: false,
      duration: 0,
      speed: Speed(speed: 1),
      volume: 100,
      track: Track(
        id: '',
        title: '',
        fileId: '',
        description: '',
        imageUrl: '',
        artist: '',
      ),
    );

    if (Platform.isIOS) {
      iosAudioHandler.iosStateStream.listen(
        (event) {
          var playerState = event.playerState;
          state = state.copyWith(
            speed: Speed(speed: event.speed),
            track: iosAudioHandler.trackState,
            isPlaying: event.playerState.playing,
            isBuffering:
                playerState.processingState == ProcessingState.buffering,
            isSeeking: false,
            isCompleted:
                playerState.processingState == ProcessingState.completed,
            position: event.position.inMilliseconds,
            duration: event.duration.inMilliseconds,
          );
        },
      );
    }

    return initialState;
  }

  void updatePlaybackState(PlaybackState newState) {
    state = newState;
  }

  void resetState() {
    state = PlaybackState(
      position: 0,
      isPlaying: false,
      isBuffering: false,
      isSeeking: false,
      isCompleted: false,
      duration: 0,
      speed: Speed(speed: 1),
      volume: 100,
      track: Track(
        id: '',
        title: '',
        fileId: '',
        description: '',
        imageUrl: '',
        artist: '',
      ),
    );
  }
}

var audioStateNotifier = AudioStateNotifier();

final audioStateProvider =
    NotifierProvider<AudioStateNotifier, PlaybackState>(() {
  return audioStateNotifier;
});

extension PlaybackStateExt on PlaybackState {
  PlaybackState copyWith({
    int? position,
    bool? isPlaying,
    bool? isBuffering,
    bool? isSeeking,
    bool? isCompleted,
    int? duration,
    Speed? speed,
    int? volume,
    Track? track,
  }) {
    return PlaybackState(
      position: position ?? this.position,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isSeeking: isSeeking ?? this.isSeeking,
      isCompleted: isCompleted ?? this.isCompleted,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      volume: volume ?? this.volume,
      track: track ?? this.track,
    );
  }
}

class UpdateStatsConstants {
  static const userTokenKey = 'userToken';
}
