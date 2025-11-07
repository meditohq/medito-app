import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../l10n/app_localizations.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  SharedPreferences? _prefs;

  ThemeNotifier() : super(ThemeMode.dark) {
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadTheme();
  }

  void _loadTheme() {
    final savedTheme =
        _prefs?.getString(SharedPreferenceConstants.themePreference);

    switch (savedTheme) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'system':
        state = ThemeMode.system;
        break;
      default:
        // Default to dark theme for new users
        state = ThemeMode.dark;
        break;
    }
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    // Ensure prefs are initialized
    _prefs ??= await SharedPreferences.getInstance();

    String themeString;
    switch (themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }

    await _prefs!
        .setString(SharedPreferenceConstants.themePreference, themeString);
    state = themeMode;
  }

  String getCurrentThemeString() {
    switch (state) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  String getThemeDisplayName(BuildContext context) {
    // Import AppLocalizations at the top of the file
    final l10n = AppLocalizations.of(context)!;

    switch (state) {
      case ThemeMode.light:
        return l10n.lightTheme;
      case ThemeMode.dark:
        return l10n.darkTheme;
      case ThemeMode.system:
        return l10n.systemTheme;
    }
  }
}
