import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/providers/locale_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<ProviderContainer> makeContainer({
    String? saved,
    List<Locale> device = const [Locale('en')],
  }) async {
    SharedPreferences.setMockInitialValues({
      SharedPreferenceConstants.localePreference: ?saved,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        deviceLocalesProvider.overrideWithValue(device),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('LocaleNotifier', () {
    test('follows a supported device language by default', () async {
      final c = await makeContainer(device: const [Locale('es', 'ES')]);
      expect(c.read(localeProvider), const Locale('es'));
    });

    test('uses the first supported language in device order', () async {
      final c = await makeContainer(
        device: const [Locale('fr'), Locale('de'), Locale('es')],
      );
      expect(c.read(localeProvider), const Locale('de'));
    });

    test('falls back to English, not the first supported locale', () async {
      final c = await makeContainer(device: const [Locale('fr')]);
      expect(c.read(localeProvider), const Locale('en'));
    });

    test('honours a saved explicit language over the device', () async {
      final c = await makeContainer(
        saved: 'es',
        device: const [Locale('de')],
      );
      expect(c.read(localeProvider), const Locale('es'));
    });

    test('an unknown saved language falls back to English', () async {
      final c = await makeContainer(saved: 'xx', device: const [Locale('es')]);
      expect(c.read(localeProvider), const Locale('en'));
    });

    test('setLocale persists and applies the choice', () async {
      final c = await makeContainer(device: const [Locale('en')]);
      await c.read(localeProvider.notifier).setLocale('es');
      expect(c.read(localeProvider), const Locale('es'));
      expect(c.read(localeProvider.notifier).getCurrentLocaleSetting(), 'es');

      await c.read(localeProvider.notifier).setLocale('system');
      expect(c.read(localeProvider), const Locale('en'));
    });
  });
}
