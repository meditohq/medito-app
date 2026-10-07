import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';

class TimerSettings {
  const TimerSettings({required this.mode, required this.minutes});

  final TimerMode mode;

  /// Countdown length. Kept while in stopwatch mode so switching back
  /// restores it.
  final int minutes;

  Duration get countdown => Duration(minutes: minutes);

  /// What a session started now would last.
  Duration get sessionDuration =>
      mode == TimerMode.stopwatch ? kStopwatchMaxDuration : countdown;

  bool get canStart => mode == TimerMode.stopwatch || minutes > 0;

  TimerSettings copyWith({TimerMode? mode, int? minutes}) =>
      TimerSettings(mode: mode ?? this.mode, minutes: minutes ?? this.minutes);
}

/// The Timer screen's mode and countdown length. The length is persisted so
/// the next visit opens on it (70% of timer sessions repeat the previous
/// length, Sep 2026); the screen always opens on the countdown.
// autoDispose: dropped when the Timer screen closes, so each visit starts on
// the countdown again (the player route sits above it, so it survives the
// session itself).
final timerSettingsProvider =
    NotifierProvider.autoDispose<TimerSettingsNotifier, TimerSettings>(
      TimerSettingsNotifier.new,
    );

class TimerSettingsNotifier extends Notifier<TimerSettings> {
  static const _maxMinutes = kMaxTimerHours * 60 + 59;

  @override
  TimerSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final minutes = prefs.getInt(SharedPreferenceConstants.timerMinutes);
    return TimerSettings(
      mode: TimerMode.countdown,
      minutes: (minutes ?? kDefaultTimerMinutes).clamp(0, _maxMinutes),
    );
  }

  void setMode(TimerMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
  }

  void setMinutes(int minutes) {
    final clamped = minutes.clamp(0, _maxMinutes);
    if (clamped == state.minutes) return;
    state = state.copyWith(minutes: clamped);
    ref
        .read(sharedPreferencesProvider)
        .setInt(SharedPreferenceConstants.timerMinutes, clamped);
  }
}
