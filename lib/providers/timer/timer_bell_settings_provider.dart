import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/repositories/background_sounds/background_sounds_repository.dart';

/// The timer's saved bell choices, shared by setup and its player sound sheet.
/// Updating setup only saves preferences; it never changes active playback.
final timerBellSettingsProvider =
    NotifierProvider.autoDispose<TimerBellSettingsNotifier, SessionBellPattern>(
      TimerBellSettingsNotifier.new,
    );

class TimerBellSettingsNotifier extends Notifier<SessionBellPattern> {
  @override
  SessionBellPattern build() {
    final repo = ref.watch(backgroundSoundsRepositoryProvider);
    return repo.getSessionBellsEnabled(forTimer: true)
        ? repo.getSessionBellPattern(forTimer: true)
        : SessionBellPattern.none;
  }

  void setCue(SessionBellCue cue, bool selected) =>
      setPattern(state.withCue(cue, selected));

  void setPattern(SessionBellPattern pattern) {
    if (pattern == state) return;
    final repo = ref.read(backgroundSoundsRepositoryProvider);
    repo.saveSessionBellPattern(pattern, forTimer: true);
    repo.saveSessionBellsEnabled(
      pattern != SessionBellPattern.none,
      forTimer: true,
    );
    state = pattern;
  }
}
