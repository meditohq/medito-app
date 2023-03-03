import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioPlayPauseStateProvider = StateProvider<PLAY_PAUSE_AUDIO>(
  (ref) {
    final audioPlayer = ref.read(audioPlayerNotifierProvider);
    audioPlayer.playSessionAudio();
    return PLAY_PAUSE_AUDIO.PLAY;
  },
);

final audioPlayPauseProvider = Provider<PLAY_PAUSE_AUDIO>((ref) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  final currentState = ref.watch(audioPlayPauseStateProvider);
  if (currentState == PLAY_PAUSE_AUDIO.PLAY) {
    audioPlayer.playSessionAudio();
    return PLAY_PAUSE_AUDIO.PLAY;
  } else {
    audioPlayer.pauseSessionAudio();
    return PLAY_PAUSE_AUDIO.PAUSE;
  }
});

enum PLAY_PAUSE_AUDIO { PLAY, PAUSE }
