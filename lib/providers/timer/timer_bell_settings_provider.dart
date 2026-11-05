import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/repositories/background_sounds/background_sounds_repository.dart';

/// Interval-bell options offered on the Timer and Stopwatch, in seconds.
/// 0 is the "Off" chip; the rest are 1, 2, 5, 10 and 15 minutes.
const kTimerBellIntervalOptionsSeconds = [0, 60, 120, 300, 600, 900];

class TimerBellSettings {
  const TimerBellSettings({
    required this.pattern,
    required this.intervalSeconds,
  });

  final SessionBellPattern pattern;

  /// Seconds between interval bells on top of the pattern cues, or 0 for off.
  final int intervalSeconds;

  /// Any bell at all — a pattern cue or an interval tick.
  bool get hasAnyBell =>
      pattern != SessionBellPattern.none || intervalSeconds > 0;

  TimerBellSettings copyWith({SessionBellPattern? pattern, int? intervalSeconds}) =>
      TimerBellSettings(
        pattern: pattern ?? this.pattern,
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      );
}

/// The timer's saved bell choices, shared by setup and its player sound sheet.
/// Updating setup only saves preferences; it never changes active playback.
final timerBellSettingsProvider =
    NotifierProvider.autoDispose<TimerBellSettingsNotifier, TimerBellSettings>(
      TimerBellSettingsNotifier.new,
    );

class TimerBellSettingsNotifier extends Notifier<TimerBellSettings> {
  @override
  TimerBellSettings build() {
    final repo = ref.watch(backgroundSoundsRepositoryProvider);
    final pattern = repo.getSessionBellsEnabled(forTimer: true)
        ? repo.getSessionBellPattern(forTimer: true)
        : SessionBellPattern.none;
    return TimerBellSettings(
      pattern: pattern,
      intervalSeconds: repo.getTimerBellIntervalSeconds(),
    );
  }

  void setCue(SessionBellCue cue, bool selected) =>
      setPattern(state.pattern.withCue(cue, selected));

  void setPattern(SessionBellPattern pattern) {
    if (pattern == state.pattern) return;
    final repo = ref.read(backgroundSoundsRepositoryProvider);
    repo.saveSessionBellPattern(pattern, forTimer: true);
    repo.saveSessionBellsEnabled(
      pattern != SessionBellPattern.none,
      forTimer: true,
    );
    state = state.copyWith(pattern: pattern);
  }

  void setIntervalSeconds(int seconds) {
    if (seconds == state.intervalSeconds) return;
    final repo = ref.read(backgroundSoundsRepositoryProvider);
    repo.saveTimerBellIntervalSeconds(seconds);
    state = state.copyWith(intervalSeconds: seconds);
  }
}
