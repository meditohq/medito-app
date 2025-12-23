import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';

class ReminderPromptNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(
          SharedPreferenceConstants.reminderPromptDismissedForever,
        ) ??
        false;
  }

  Future<void> dismissForever() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(
      SharedPreferenceConstants.reminderPromptDismissedForever,
      true,
    );
    state = true;
  }
}

final reminderPromptDismissedProvider =
    NotifierProvider<ReminderPromptNotifier, bool>(
  () => ReminderPromptNotifier(),
);

final shouldShowReminderPromptProvider = Provider<bool>((ref) {
  final isReminderEnabled = ref.watch(reminderEnabledProvider);
  final isDismissed = ref.watch(reminderPromptDismissedProvider);
  return !isReminderEnabled && !isDismissed;
});


