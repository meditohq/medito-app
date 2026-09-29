import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/settings/account_prompt_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AccountPromptNotifier', () {
    late SharedPreferences prefs;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() async {
      container.dispose();
      await prefs.clear();
    });

    test('starts not dismissed and not snoozed', () {
      final state = container.read(accountPromptDismissedProvider);
      expect(state.dismissedForever, isFalse);
      expect(state.isSnoozed, isFalse);
    });

    test('dismissForever persists and is reflected in state', () async {
      await container
          .read(accountPromptDismissedProvider.notifier)
          .dismissForever();

      expect(
        container.read(accountPromptDismissedProvider).dismissedForever,
        isTrue,
      );
      expect(
        prefs.getBool(SharedPreferenceConstants.accountPromptDismissedForever),
        isTrue,
      );
    });

    test('snooze suppresses now but not ~8 days out', () async {
      await container.read(accountPromptDismissedProvider.notifier).snooze();

      final state = container.read(accountPromptDismissedProvider);
      expect(state.isSnoozed, isTrue);

      final until = prefs.getInt(
        SharedPreferenceConstants.accountPromptSnoozeUntil,
      );
      expect(until, isNotNull);

      // Snooze window is 7 days; a timestamp 8 days out is past it.
      final eightDays = DateTime.now().add(const Duration(days: 8));
      expect(until! < eightDays.millisecondsSinceEpoch, isTrue);
      // ...and still ahead of now (within the window).
      expect(until > DateTime.now().millisecondsSinceEpoch, isTrue);
    });

    test('a snooze timestamp already in the past is not snoozed', () async {
      final past = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch;
      await prefs.setInt(
        SharedPreferenceConstants.accountPromptSnoozeUntil,
        past,
      );

      // Rebuild the notifier from the seeded prefs.
      final fresh = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(fresh.dispose);

      expect(fresh.read(accountPromptDismissedProvider).isSnoozed, isFalse);
    });
  });
}
