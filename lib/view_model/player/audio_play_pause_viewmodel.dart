import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioPlayPauseStateProvider = StateProvider<PLAY_PAUSE_AUDIO>(
  (ref) {
    final audioPlayer = ref.read(audioPlayerNotifierProvider);
    audioPlayer.play();

    return PLAY_PAUSE_AUDIO.PLAY;
  },
);

final audioPlayPauseProvider = Provider.family<PLAY_PAUSE_AUDIO, bool?>(
  (ref, hasBackgroundSound) {
    final audioPlayer = ref.watch(audioPlayerNotifierProvider);
    final currentState = ref.watch(audioPlayPauseStateProvider);
    if (currentState == PLAY_PAUSE_AUDIO.PLAY) {
      audioPlayer.play();
      if (hasBackgroundSound != null && hasBackgroundSound) {
        audioPlayer.playBackgroundSound();
      }
      
      return PLAY_PAUSE_AUDIO.PLAY;
    } else {
      audioPlayer.pause();
      if (hasBackgroundSound != null && hasBackgroundSound) {
        audioPlayer.pauseBackgroundSound();
      }

      return PLAY_PAUSE_AUDIO.PAUSE;
    }
  },
);

//ignore: prefer-match-file-name
enum PLAY_PAUSE_AUDIO { PLAY, PAUSE }
