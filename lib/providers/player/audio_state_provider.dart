import 'package:Medito/main.dart';
import 'package:Medito/providers/player/player_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../../src/audio_pigeon.g.dart';

final trackStateSubject = BehaviorSubject<Track>();

Track get _trackState => trackStateSubject.value;

Stream<Track> get _trackStateStream => trackStateSubject.stream;

class AudioStateProvider implements MeditoAudioServiceCallbackApi {
  final AudioStateNotifier notifier;

  AudioStateProvider(this.notifier);

  @override
  void updatePlaybackState(PlaybackState state) {
    notifier.updatePlaybackState(state);
  }
}

class AudioStateNotifier extends StateNotifier<PlaybackState> {
  Stream<IosStateData> get _iosStateStream => Rx.combineLatest5<PlayerState,
          Track, Duration, Duration, Duration?, IosStateData>(
        iosPlayer.playerStateStream,
        _trackStateStream,
        iosPlayer.positionStream,
        iosPlayer.bufferedPositionStream,
        iosPlayer.durationStream,
        (state, track, position, bufferedPosition, duration) => IosStateData(
          state,
          track,
          position,
          bufferedPosition,
          duration ?? Duration.zero,
        ),
      );

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
              title: '',
              description: '',
              imageUrl: '',
              artist: '',
            ),
          ),
        ) {
    _iosStateStream.listen(
      (event) {
        var playerState = event.playerState;
        state = state.copyWith(
          track: _trackState,
          isPlaying: event.playerState.playing,
          isBuffering: playerState.processingState == ProcessingState.buffering,
          isSeeking: false,
          isCompleted: playerState.processingState == ProcessingState.completed,
          position: event.position.inMilliseconds,
          duration: event.duration.inMilliseconds,
        );
      },
    );
    iosPlayer.speedStream.listen((event) {
      state = state.copyWith(speed: Speed(speed: event));
    });
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
      track: Track(title: '', description: '', imageUrl: '', artist: ''),
    );
  }
}

class IosStateData {
  final PlayerState playerState;
  final Track track;
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  IosStateData(
    this.playerState,
    this.track,
    this.position,
    this.bufferedPosition,
    this.duration,
  );
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