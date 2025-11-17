import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../src/audio_pigeon.g.dart';
import '../../utils/logger.dart';

part 'repeat_state_provider.g.dart';

@riverpod
class RepeatState extends _$RepeatState {
  @override
  RepeatMode build() {
    return RepeatMode.none;
  }

  RepeatMode toggleRepeat() {
    AppLogger.d('REPEAT', 'Current state before toggle: $state');
    final newMode = switch (state) {
      RepeatMode.none => RepeatMode.once,
      RepeatMode.once => RepeatMode.infinite,
      RepeatMode.infinite => RepeatMode.none,
    };
    state = newMode;
    AppLogger.d('REPEAT', 'New state after toggle: $newMode');
    return newMode;
  }

  void setRepeatMode(RepeatMode mode) {
    state = mode;
  }

  bool get isRepeating => state != RepeatMode.none;
  bool get isRepeatingInfinite => state == RepeatMode.infinite;
  bool get isRepeatingOnce => state == RepeatMode.once;
}
