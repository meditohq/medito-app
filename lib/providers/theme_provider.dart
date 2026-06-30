import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/strings/shared_preference_constants.dart';
import '../l10n/app_localizations.dart';
import '../services/home_widget_service.dart';
import 'shared_preference/shared_preference_provider.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final savedTheme = prefs.getString(
      SharedPreferenceConstants.themePreference,
    );

    ThemeMode themeMode;
    switch (savedTheme) {
      case 'light':
        themeMode = ThemeMode.light;
        break;
      case 'dark':
        themeMode = ThemeMode.dark;
        break;
      case 'system':
        themeMode = ThemeMode.system;
        break;
      default:
        // Default to dark theme for new users
        themeMode = ThemeMode.dark;
        break;
    }

    // Save theme preference to widget when loading
    if (savedTheme != null) {
      HomeWidgetService.saveThemePreference(savedTheme);
    }

    return themeMode;
  }

  Future<void> setTheme(ThemeMode themeMode) async {
    final prefs = ref.read(sharedPreferencesProvider);

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

    await prefs.setString(
      SharedPreferenceConstants.themePreference,
      themeString,
    );
    state = themeMode;

    // Save theme preference to widget
    await HomeWidgetService.saveThemePreference(themeString);
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
