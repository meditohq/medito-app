import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // A time chip saves the hour before permission is asked. If the user then
  // declines, the saved time alone must not make the app think reminders are on.
  group('declining the reminder permission after picking a time', () {
    Future<ProviderContainer> containerWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      return container;
    }

    final chipPicked = <String, Object>{
      SharedPreferenceConstants.savedHours: 21,
      SharedPreferenceConstants.savedMinutes: 0,
    };

    test('a saved time with no flag reads as enabled (the bug)', () async {
      final container = await containerWith(chipPicked);

      expect(container.read(reminderEnabledProvider), isTrue);
      expect(container.read(shouldShowReminderPromptProvider), isFalse);
    });

    test('recordReminderNotEnabled makes the end-screen card show', () async {
      final container = await containerWith(chipPicked);
      final prefs = container.read(sharedPreferencesProvider);

      await recordReminderNotEnabled(prefs);
      container.invalidate(reminderEnabledProvider);

      expect(container.read(reminderEnabledProvider), isFalse);
      expect(container.read(shouldShowReminderPromptProvider), isTrue);
    });

    test('keeps the chosen time so a later enable can reuse it', () async {
      final container = await containerWith(chipPicked);
      final prefs = container.read(sharedPreferencesProvider);

      await recordReminderNotEnabled(prefs);

      expect(prefs.getInt(SharedPreferenceConstants.savedHours), 21);
      expect(prefs.getInt(SharedPreferenceConstants.savedMinutes), 0);
    });
  });

  group('repairReminderFlagOnce', () {
    Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
      SharedPreferences.setMockInitialValues(values);
      return SharedPreferences.getInstance();
    }

    final declined = <String, Object>{
      SharedPreferenceConstants.savedHours: 8,
      SharedPreferenceConstants.savedMinutes: 0,
    };

    test('saved time + no flag + no permission -> writes false', () async {
      final prefs = await prefsWith(declined);
      await repairReminderFlagOnce(prefs, isGranted: () async => false);
      expect(
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled),
        isFalse,
      );
      expect(prefs.getInt(SharedPreferenceConstants.savedHours), 8);
    });

    test('permission granted -> left alone', () async {
      final prefs = await prefsWith(declined);
      await repairReminderFlagOnce(prefs, isGranted: () async => true);
      expect(
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled),
        isNull,
      );
    });

    test('explicit flag is never overwritten', () async {
      final prefs = await prefsWith({
        ...declined,
        SharedPreferenceConstants.dailyReminderEnabled: true,
      });
      await repairReminderFlagOnce(prefs, isGranted: () async => false);
      expect(
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled),
        isTrue,
      );
    });

    test('runs only once', () async {
      final prefs = await prefsWith(declined);
      await repairReminderFlagOnce(prefs, isGranted: () async => true);
      await prefs.remove(SharedPreferenceConstants.dailyReminderEnabled);
      var asked = false;
      await repairReminderFlagOnce(
        prefs,
        isGranted: () async {
          asked = true;
          return false;
        },
      );
      expect(asked, isFalse);
      expect(
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled),
        isNull,
      );
    });
  });
}
