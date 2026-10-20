import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/background_sounds/session_bell_pattern.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/providers/timer/timer_bell_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    container.listen(timerBellSettingsProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  test('timer setup defaults to beginning and end', () async {
    final container = await containerWith({});
    expect(
      container.read(timerBellSettingsProvider),
      SessionBellPattern.beginningEnd,
    );
  });

  test(
    'setup changes save timer preferences without changing regular sessions',
    () async {
      final container = await containerWith({
        SharedPreferenceConstants.sessionBellsEnabled: true,
        SharedPreferenceConstants.sessionBellPattern: 'middle',
      });
      final notifier = container.read(timerBellSettingsProvider.notifier);
      notifier.setCue(SessionBellCue.beginning, false);
      notifier.setCue(SessionBellCue.middle, true);
      final prefs = container.read(sharedPreferencesProvider);
      expect(
        container.read(timerBellSettingsProvider),
        SessionBellPattern.middleEnd,
      );
      expect(
        prefs.getString(SharedPreferenceConstants.timerSessionBellPattern),
        'middleEnd',
      );
      expect(
        prefs.getBool(SharedPreferenceConstants.timerSessionBellsEnabled),
        isTrue,
      );
      expect(
        prefs.getString(SharedPreferenceConstants.sessionBellPattern),
        'middle',
      );
      expect(
        prefs.getBool(SharedPreferenceConstants.sessionBellsEnabled),
        isTrue,
      );
      container.invalidate(timerBellSettingsProvider);
      expect(
        container.read(timerBellSettingsProvider),
        SessionBellPattern.middleEnd,
      );
    },
  );

  test('clearing all cues stays silent when setup reopens', () async {
    final container = await containerWith({});
    container.read(timerBellSettingsProvider.notifier)
      ..setCue(SessionBellCue.beginning, false)
      ..setCue(SessionBellCue.end, false);
    container.invalidate(timerBellSettingsProvider);
    expect(container.read(timerBellSettingsProvider), SessionBellPattern.none);
  });

  test('an existing timer opt-out is shown as all three unchecked', () async {
    final container = await containerWith({
      SharedPreferenceConstants.timerSessionBellsEnabled: false,
      SharedPreferenceConstants.timerSessionBellPattern: 'beginningEnd',
    });
    expect(container.read(timerBellSettingsProvider), SessionBellPattern.none);
    container
        .read(timerBellSettingsProvider.notifier)
        .setCue(SessionBellCue.middle, true);
    expect(
      container.read(timerBellSettingsProvider),
      SessionBellPattern.middle,
    );
  });
}
