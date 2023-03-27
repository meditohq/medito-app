import 'package:Medito/view_model/audio_player/audio_player_viewmodel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'audio_position_viewmodel.g.dart';

@riverpod
void slideAudioPosition(
  SlideAudioPositionRef ref, {
  required int duration,
}) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  audioPlayer.seekValueFromSlider(duration);
}

@riverpod
void skipAudio(
  SkipAudioRef ref, {
  required SKIP_AUDIO skip,
}) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  switch (skip) {
    case SKIP_AUDIO.SKIP_FORWARD_30:
      audioPlayer.skipForward30Secs();
      break;
    case SKIP_AUDIO.SKIP_BACKWARD_10:
      audioPlayer.skipBackward10Secs();
      break;
  }
}

final audioPositionProvider = StreamProvider.autoDispose<int>((ref) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  return audioPlayer.sessionAudioPlayer.positionStream
      .map((position) => position.inMilliseconds);
});

enum SKIP_AUDIO { SKIP_FORWARD_30, SKIP_BACKWARD_10 }
