import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/settings/reminder_prompt_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/stats_provider.dart';

/// How long a soft dismiss ("Not now") suppresses the account-conversion prompt.
const Duration _snoozeDuration = Duration(days: 7);

/// Minimum completed sessions before the prompt appears. The pitch is "keep your
/// streak/history safe", so we wait until the user has a streak worth keeping —
/// showing it on session #1 asks people to protect nothing.
const int _minCompletedSessions = 2;

class AccountPromptNotifier extends Notifier<AccountPromptState> {
  @override
  AccountPromptState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AccountPromptState(
      dismissedForever:
          prefs.getBool(
            SharedPreferenceConstants.accountPromptDismissedForever,
          ) ??
          false,
      snoozeUntilMillis: prefs.getInt(
        SharedPreferenceConstants.accountPromptSnoozeUntil,
      ),
    );
  }

  Future<void> dismissForever() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
      SharedPreferenceConstants.accountPromptDismissedForever,
      true,
    );
    state = state.copyWith(dismissedForever: true);
  }

  Future<void> snooze() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final until = DateTime.now().add(_snoozeDuration).millisecondsSinceEpoch;
    await prefs.setInt(
      SharedPreferenceConstants.accountPromptSnoozeUntil,
      until,
    );
    state = state.copyWith(snoozeUntilMillis: until);
  }
}

class AccountPromptState {
  const AccountPromptState({
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

  AccountPromptState copyWith({
    bool? dismissedForever,
    int? snoozeUntilMillis,
  }) => AccountPromptState(
    dismissedForever: dismissedForever ?? this.dismissedForever,
    snoozeUntilMillis: snoozeUntilMillis ?? this.snoozeUntilMillis,
  );
}

final accountPromptDismissedProvider =
    NotifierProvider<AccountPromptNotifier, AccountPromptState>(
      () => AccountPromptNotifier(),
    );

/// Whether to show the end-screen account-conversion card.
///
/// Gates:
/// - user is anonymous (no email on their account yet);
/// - the reminder soft-ask is not being shown (one soft-ask per end screen,
///   and the reminder card owns the first slot);
/// - the user has completed at least [_minCompletedSessions] sessions;
/// - the prompt has not been permanently dismissed or snoozed.
final shouldShowAccountPromptProvider = Provider<bool>((ref) {
  final me = ref.watch(meProvider).value;
  final isAnonymous = me == null || (me.email?.isEmpty ?? true);
  if (!isAnonymous) return false;

  // Never stack two soft-asks; the reminder prompt takes precedence.
  if (ref.watch(shouldShowReminderPromptProvider)) return false;

  final completed = ref.watch(statsProvider).value?.totalTracksCompleted ?? 0;
  if (completed < _minCompletedSessions) return false;

  final promptState = ref.watch(accountPromptDismissedProvider);
  return !promptState.dismissedForever && !promptState.isSnoozed;
});
