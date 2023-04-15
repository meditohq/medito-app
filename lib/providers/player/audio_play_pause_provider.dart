import 'package:Medito/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioPlayPauseStateProvider = StateProvider<PLAY_PAUSE_AUDIO>(
  (ref) {
    return PLAY_PAUSE_AUDIO.PLAY;
  },
);

final audioPlayPauseProvider = Provider<void>(
  (ref) {
    final audioPlayer = ref.watch(audioPlayerNotifierProvider);
    final currentState = ref.watch(audioPlayPauseStateProvider);
    if (currentState == PLAY_PAUSE_AUDIO.PLAY) {
      audioPlayer.play();
    } else {
      audioPlayer.pause();
    }
  },
);

//ignore: prefer-match-file-name
enum PLAY_PAUSE_AUDIO { PLAY, PAUSE }
