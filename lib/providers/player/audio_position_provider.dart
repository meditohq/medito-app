import 'package:Medito/providers/providers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';

part 'audio_position_provider.g.dart';

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
    case SKIP_AUDIO.SKIP_FORWARD_10:
      audioPlayer.skipForward10Secs();
      break;
    case SKIP_AUDIO.SKIP_BACKWARD_10:
      audioPlayer.skipBackward10Secs();
      break;
  }
}

final audioPositionAndPlayerStateProvider =
    StreamProvider<PositionAndPlayerStateState>((ref) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);

  return Rx.combineLatest3<Duration, Duration?, PlayerState,
      PositionAndPlayerStateState>(
    audioPlayer.trackAudioPlayer.positionStream,
    audioPlayer.trackAudioPlayer.durationStream,
    audioPlayer.trackAudioPlayer.playerStateStream,
    (position, duration, playerState) =>
        PositionAndPlayerStateState(playerState, duration, position),
  );
});

final audioPlaybackStreamProvider = StreamProvider<ProcessingState>((ref) {
  final audioPlayer = ref.watch(audioPlayerNotifierProvider);

  return audioPlayer.trackAudioPlayer.playbackEventStream
      .map((event) => event.processingState);
});

//ignore: prefer-match-file-name
enum SKIP_AUDIO { SKIP_FORWARD_10, SKIP_BACKWARD_10 }

class PositionAndPlayerStateState {
  final PlayerState playerState;
  final Duration position;
  final Duration? duration;

  PositionAndPlayerStateState(this.playerState, this.duration, this.position);
}
