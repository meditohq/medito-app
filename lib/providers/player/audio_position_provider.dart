import 'package:Medito/providers/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'audio_position_provider.g.dart';

@riverpod
void slideAudioPosition(
  ref, {
  required int duration,
}) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  audioPlayer.seekValueFromSlider(duration);
}

@riverpod
void skipAudio(
  ref, {
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

//ignore: prefer-match-file-name
enum SKIP_AUDIO { SKIP_FORWARD_30, SKIP_BACKWARD_10 }
