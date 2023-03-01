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

final audioPositionProvider = StreamProvider.autoDispose<int>((ref) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);
  return audioPlayer.sessionAudioPlayer.positionStream
      .map((position) => position.inMilliseconds);
});
