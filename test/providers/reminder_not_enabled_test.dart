import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/settings/reminder_prompt_provider.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
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
}
