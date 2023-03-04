import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_play_pause_viewmodel.dart';

final audioCompletionProvider = StreamProvider.family
    .autoDispose<void, int>((ref, totalDurationInMilliSeconds) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);

  return audioPlayer.sessionAudioPlayer.positionStream.map((position) {
    if (totalDurationInMilliSeconds <= position.inMilliseconds) {
      audioPlayer.seekValueFromSlider(0);
      audioPlayer.pauseSessionAudio();
      audioPlayer.pauseBackgroundSound();
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PAUSE;
    }
  });
});
