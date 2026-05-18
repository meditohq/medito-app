import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';

/// How long a soft dismiss ("Not now") suppresses the prompt.
///
/// The prompt is shown on every end-screen visit (including session #1) by
/// design: BigQuery says ~28% of users who complete a session never do a
/// second one, so gating on a return visit would miss the cohort most at
/// risk of churn — exactly the users a reminder would help retain.
const Duration _snoozeDuration = Duration(days: 7);

class ReminderPromptNotifier extends Notifier<ReminderPromptState> {
  @override
  ReminderPromptState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return ReminderPromptState(
      dismissedForever: prefs.getBool(
            SharedPreferenceConstants.reminderPromptDismissedForever,
          ) ??
          false,
      snoozeUntilMillis: prefs.getInt(
        SharedPreferenceConstants.reminderPromptSnoozeUntil,
      ),
    );
  }

  Future<void> dismissForever() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
      SharedPreferenceConstants.reminderPromptDismissedForever,
      true,
    );
    state = state.copyWith(dismissedForever: true);
  }

  Future<void> snooze() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final until = DateTime.now().add(_snoozeDuration).millisecondsSinceEpoch;
    await prefs.setInt(
      SharedPreferenceConstants.reminderPromptSnoozeUntil,
      until,
    );
    state = state.copyWith(snoozeUntilMillis: until);
  }
}

class ReminderPromptState {
  const ReminderPromptState({
    required this.dismissedForever,
    this.snoozeUntilMillis,
  });

  final bool dismissedForever;
  final int? snoozeUntilMillis;

  bool get isSnoozed {
    final until = snoozeUntilMillis;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  ReminderPromptState copyWith({
    bool? dismissedForever,
    int? snoozeUntilMillis,
  }) =>
      ReminderPromptState(
        dismissedForever: dismissedForever ?? this.dismissedForever,
        snoozeUntilMillis: snoozeUntilMillis ?? this.snoozeUntilMillis,
      );
}

final reminderPromptDismissedProvider =
    NotifierProvider<ReminderPromptNotifier, ReminderPromptState>(
  () => ReminderPromptNotifier(),
);

final shouldShowReminderPromptProvider = Provider<bool>((ref) {
  final isReminderEnabled = ref.watch(reminderEnabledProvider);
  if (isReminderEnabled) return false;

  final promptState = ref.watch(reminderPromptDismissedProvider);
  return !promptState.dismissedForever && !promptState.isSnoozed;
});


