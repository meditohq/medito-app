import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../constants/types/type_constants.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale?> {
  SharedPreferences? _prefs;

  LocaleNotifier() : super(null) {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadLocale();
  }

  void _loadLocale() {
    if (_prefs == null) return;

    final savedLocale =
        _prefs!.getString(SharedPreferenceConstants.localePreference);

    if (savedLocale == null || savedLocale == LocaleConstants.system) {
      // Force English until backend is ready for Spanish
      state = const Locale(LocaleConstants.english);
    } else {
      // Force English even if Spanish was previously selected
      state = const Locale(LocaleConstants.english);
    }
  }

  Future<void> setLocale(String localeCode) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    await _prefs!
        .setString(SharedPreferenceConstants.localePreference, localeCode);

    // Force English until backend is ready for Spanish
    state = const Locale(LocaleConstants.english);
  }

  String getCurrentLocaleSetting() {
    return _prefs?.getString(SharedPreferenceConstants.localePreference) ??
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
