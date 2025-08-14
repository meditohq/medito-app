import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      // Use system locale
      final systemLocale = PlatformDispatcher.instance.locale;
      if (systemLocale.languageCode == LocaleConstants.spanish) {
        state = const Locale(LocaleConstants.spanish);
      } else {
        state = const Locale(LocaleConstants.english);
      }
    } else {
      state = Locale(savedLocale);
    }
  }

  Future<void> setLocale(String localeCode) async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }

    await _prefs!
        .setString(SharedPreferenceConstants.localePreference, localeCode);

    if (localeCode == LocaleConstants.system) {
      // Use system locale
      final systemLocale = PlatformDispatcher.instance.locale;
      if (systemLocale.languageCode == LocaleConstants.spanish) {
        state = const Locale(LocaleConstants.spanish);
      } else {
        state = const Locale(LocaleConstants.english);
      }
    } else {
      state = Locale(localeCode);
    }
  }

  String getCurrentLocaleSetting() {
    return _prefs?.getString(SharedPreferenceConstants.localePreference) ??
        LocaleConstants.system;
  }

  String getLocaleDisplayName(String localeCode) {
    switch (localeCode) {
      case LocaleConstants.system:
        return 'System';
      case LocaleConstants.english:
        return 'English';
      case LocaleConstants.spanish:
        return 'Español';
      default:
        return 'System';
    }
  }
}
