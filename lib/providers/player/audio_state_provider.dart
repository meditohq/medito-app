import 'package:Medito/main.dart';
import 'package:Medito/providers/player/player_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../src/audio_pigeon.g.dart';

class AudioStateProvider implements MeditoAudioServiceCallbackApi {
  final AudioStateNotifier notifier;

  AudioStateProvider(this.notifier);

  @override
  void updatePlaybackState(PlaybackState state) {
    notifier.updatePlaybackState(state);
  }
}

class AudioStateNotifier extends StateNotifier<PlaybackState> {
  AudioStateNotifier()
      : super(
          PlaybackState(
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
              description: '',
              imageUrl: '',
              artist: '',
            ),
          ),
        ) {
    iosAudioHandler.iosStateStream.listen(
      (event) {
        var playerState = event.playerState;
        state = state.copyWith(
          speed: Speed(speed: event.speed),
          track: iosAudioHandler.trackState,
          isPlaying: event.playerState.playing,
          isBuffering: playerState.processingState == ProcessingState.buffering,
          isSeeking: false,
          isCompleted: playerState.processingState == ProcessingState.completed,
          position: event.position.inMilliseconds,
          duration: event.duration.inMilliseconds,
        );
      },
    );
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
      track:
          Track(id: '', title: '', description: '', imageUrl: '', artist: ''),
    );
  }
}

final audioStateProvider =
    StateNotifierProvider<AudioStateNotifier, PlaybackState>((ref) {
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
