import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../constants/types/type_constants.dart';
import 'shared_preference/shared_preference_provider.dart';

/// The device's preferred languages, in the user's order of preference
/// (Settings > Language & Region on iOS, Languages on Android). This is
/// independent of [localeProvider], which is the in-app UI language (only
/// languages with a translation); use this to tailor content to what the
/// phone says the user reads. The app root invalidates it when the device
/// languages change, so dependants re-resolve without a restart. Overridable
/// in tests.
final deviceLocalesProvider = Provider<List<Locale>>(
  (_) => PlatformDispatcher.instance.locales,
);

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    // Watched so a "system" preference follows device language changes made
    // while the app is running (see [deviceLocalesProvider]).
    ref.watch(deviceLocalesProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final savedLocale = prefs.getString(
      SharedPreferenceConstants.localePreference,
    );

    return _resolve(savedLocale);
  }

  Future<void> setLocale(String localeCode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      SharedPreferenceConstants.localePreference,
      localeCode,
    );

    state = _resolve(localeCode);
  }

  /// Resolves a saved preference to a supported UI locale. "System" (or no
  /// preference) follows the device's languages in order. Anything without a
  /// translation falls back to English rather than to the first entry of
  /// [AppLocalizations.supportedLocales], which is what [MaterialApp] would
  /// otherwise pick for an unsupported device language.
  Locale _resolve(String? localeCode) {
    if (localeCode != null && localeCode != LocaleConstants.system) {
      return _supported(localeCode) ?? const Locale(LocaleConstants.english);
    }
    for (final deviceLocale in ref.read(deviceLocalesProvider)) {
      final match = _supported(deviceLocale.languageCode);
      if (match != null) return match;
    }
    return const Locale(LocaleConstants.english);
  }

  static Locale? _supported(String languageCode) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == languageCode) return locale;
    }
    return null;
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
