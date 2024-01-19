import 'package:Medito/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      : super(PlaybackState(
          position: 0,
          isPlaying: false,
          isBuffering: false,
          isSeeking: false,
          isCompleted: false,
          duration: 0,
          speed: Speed(speed: 1),
          volume: 100,
          track: Track(title: '', description: '', imageUrl: '', artist: ''),
        ));

  void updatePlaybackState(PlaybackState newState) {
    print('updatePlaybackState state' + state.toString());
    state = newState;
  }
}

final audioStateProvider =
    StateNotifierProvider<AudioStateNotifier, PlaybackState>((ref) {
  return audioStateNotifier;
});
