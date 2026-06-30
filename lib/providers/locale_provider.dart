import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../constants/types/type_constants.dart';
import 'shared_preference/shared_preference_provider.dart';

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
      // Force English until backend is ready for Spanish
      return const Locale(LocaleConstants.english);
    } else {
      // Force English even if Spanish was previously selected
      return const Locale(LocaleConstants.english);
    }
  }

  Future<void> setLocale(String localeCode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      SharedPreferenceConstants.localePreference,
      localeCode,
    );

    // Force English until backend is ready for Spanish
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
      default:
        return AppLocalizations.of(context)!.systemLanguage;
    }
  }
}
