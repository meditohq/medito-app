import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../src/audio_pigeon.g.dart';

part 'repeat_state_provider.g.dart';

@riverpod
class RepeatState extends _$RepeatState {
  @override
  RepeatMode build() {
    return RepeatMode.none;
  }

  RepeatMode toggleRepeat() {
    switch (state) {
      case RepeatMode.none:
        state = RepeatMode.infinite;
        return RepeatMode.infinite;
      case RepeatMode.infinite:
        state = RepeatMode.none;
        return RepeatMode.none;
    }
  }

  void setRepeatMode(RepeatMode mode) {
    state = mode;
  }

  bool get isRepeating => state != RepeatMode.none;
  bool get isRepeatingInfinite => state == RepeatMode.infinite;
}
