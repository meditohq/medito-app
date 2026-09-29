import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../constants/types/type_constants.dart';
import 'shared_preference/shared_preference_provider.dart';

/// The device's preferred languages, in the user's order of preference
/// (Settings > Language & Region on iOS, Languages on Android). This is
/// independent of [localeProvider], which is the in-app language and is
/// currently pinned to English; use this to tailor content to what the
/// phone says the user reads. Overridable in tests.
final deviceLocalesProvider = Provider<List<Locale>>(
  (_) => PlatformDispatcher.instance.locales,
);

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedLocale = prefs.getString(
      SharedPreferenceConstants.localePreference,
    );

    if (savedLocale == null || savedLocale == LocaleConstants.system) {
      // Force English until backend is ready for Spanish and German
      return const Locale(LocaleConstants.english);
    } else {
      // Force English even if Spanish or German was previously selected
      return const Locale(LocaleConstants.english);
    }
  }

  Future<void> setLocale(String localeCode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      SharedPreferenceConstants.localePreference,
      localeCode,
    );

    // Force English until backend is ready for Spanish and German
    state = const Locale(LocaleConstants.english);
  }

  String getCurrentLocaleSetting() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(SharedPreferenceConstants.localePreference) ??
        LocaleConstants.system;
  }

  String getLocaleDisplayName(String localeCode, BuildContext context) {
    switch (localeCode) {
      case LocaleConstants.system:
        return AppLocalizations.of(context)!.systemLanguage;
      case LocaleConstants.english:
        return AppLocalizations.of(context)!.english;
      case LocaleConstants.spanish:
        return AppLocalizations.of(context)!.spanish;
      case LocaleConstants.german:
        return AppLocalizations.of(context)!.german;
      default:
        return AppLocalizations.of(context)!.systemLanguage;
    }
  }
}
