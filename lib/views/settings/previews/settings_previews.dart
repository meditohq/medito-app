// Widget previews for the Settings page.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// and open the printed URL. Previews render the REAL widgets against an
// in-memory SharedPreferences and a fake AuthRepository, so no backend,
// Firebase or device is needed. Edits to the settings widgets hot-reload.
//
// Reference: https://flutter.dev/to/widget-previews

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/views/settings/advanced_settings_screen.dart';
import 'package:medito/views/settings/widgets/app_icon_tile.dart';
import 'package:medito/views/settings/widgets/app_icon_option.dart';
import 'package:medito/views/settings/widgets/day_boundary_offset_dialog.dart';
import 'package:medito/views/settings/widgets/dnd_setting_tile.dart';
import 'package:medito/views/settings/widgets/reminder_tile.dart';
import 'package:medito/views/settings/widgets/theme_tile.dart';
import 'package:medito/views/settings/widgets/zen_mode_tile.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const phoneSize = Size(390, 844);

/// Preference seeds for the different states we want to look at.
const Map<String, Object> prefsDark = {
  SharedPreferenceConstants.themePreference: 'dark',
};

const Map<String, Object> prefsLight = {
  SharedPreferenceConstants.themePreference: 'light',
};

const Map<String, Object> prefsReminderOn = {
  SharedPreferenceConstants.themePreference: 'dark',
  SharedPreferenceConstants.savedHours: 7,
  SharedPreferenceConstants.savedMinutes: 30,
  SharedPreferenceConstants.dailyReminderEnabled: true,
  SharedPreferenceConstants.zenModeEnabled: true,
  SharedPreferenceConstants.dayBoundaryOffsetHours: 4,
};

/// Minimal [AuthRepository] that never touches the network.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.email});

  final String? email;

  @override
  User? get currentUser => User(id: 'preview-user', email: email);

  @override
  String? getUserEmail() => email;

  @override
  Future<String> getToken() async => 'preview-token';

  @override
  Future<void> initializeUser() async {}

  @override
  Future<bool> isLoggedIn() async => email != null;

  @override
  Future<void> migrateEmailToStorage() async {}

  @override
  Future<void> requestOtp(String email) async {}

  @override
  void resetAuthState() {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<bool> signOut() async => true;

  @override
  Future<bool> verifyOtp(String email, String otp) async => true;
}

/// Per-preview in-memory [SharedPreferences]. The real
/// `SharedPreferences.setMockInitialValues` is a process-wide singleton, so
/// previews rendered side by side would all read whichever seed was applied
/// last. Only the accessors the settings widgets use are implemented; anything
/// else falls through to [noSuchMethod].
class _MemoryPrefs implements SharedPreferences {
  _MemoryPrefs(Map<String, Object> seed) : _data = Map.of(seed);

  final Map<String, Object> _data;

  @override
  Object? get(String key) => _data[key];
  @override
  bool? getBool(String key) => _data[key] as bool?;
  @override
  int? getInt(String key) => _data[key] as int?;
  @override
  double? getDouble(String key) => _data[key] as double?;
  @override
  String? getString(String key) => _data[key] as String?;
  @override
  List<String>? getStringList(String key) =>
      (_data[key] as List?)?.cast<String>();
  @override
  bool containsKey(String key) => _data.containsKey(key);
  @override
  Set<String> getKeys() => _data.keys.toSet();

  Future<bool> _set(String key, Object value) async {
    _data[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) => _set(key, value);
  @override
  Future<bool> setInt(String key, int value) => _set(key, value);
  @override
  Future<bool> setDouble(String key, double value) => _set(key, value);
  @override
  Future<bool> setString(String key, String value) => _set(key, value);
  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _set(key, value);
  @override
  Future<bool> remove(String key) async {
    _data.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _data.clear();
    return true;
  }

  @override
  Future<void> reload() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Not supported in previews: ${invocation.memberName}',
  );
}

/// Builds the app shell (theme, l10n, Riverpod) the settings widgets expect.
class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.child,
    required this.prefs,
    this.email,
    this.themeMode = ThemeMode.dark,
    this.padded = false,
  });

  final Widget child;
  final Map<String, Object> prefs;
  final String? email;
  final ThemeMode themeMode;

  /// Wrap standalone tiles in a card-like surface with page padding.
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_MemoryPrefs(prefs)),
        authRepositorySyncProvider.overrideWithValue(
          _FakeAuthRepository(email: email),
        ),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: appTheme(context, ThemeMode.light),
          darkTheme: appTheme(context, ThemeMode.dark),
          themeMode: themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('es')],
          home: padded
              ? Scaffold(
                  body: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        child: Material(
                          type: MaterialType.transparency,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                )
              : child,
        ),
      ),
    );
  }
}

// Wrappers must be top-level functions so they can be referenced from a
// const annotation.
Widget wrapDark(Widget child) => _PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    _PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget wrapSignedIn(Widget child) => _PreviewShell(
  prefs: prefsReminderOn,
  email: 'preview@example.com',
  child: child,
);

Widget wrapDarkTile(Widget child) =>
    _PreviewShell(prefs: prefsDark, padded: true, child: child);

Widget wrapLightTile(Widget child) => _PreviewShell(
  prefs: prefsLight,
  themeMode: ThemeMode.light,
  padded: true,
  child: child,
);

Widget wrapConfiguredTile(Widget child) => _PreviewShell(
  prefs: prefsReminderOn,
  email: 'preview@example.com',
  padded: true,
  child: child,
);

// ---------------------------------------------------------------------------
// Full page
// ---------------------------------------------------------------------------

@Preview(
  group: 'Settings page',
  name: 'Signed out · dark',
  size: phoneSize,
  wrapper: wrapDark,
)
Widget settingsPageDark() => const SettingsScreen();

@Preview(
  group: 'Settings page',
  name: 'Signed out · light',
  size: phoneSize,
  wrapper: wrapLight,
)
Widget settingsPageLight() => const SettingsScreen();

@Preview(
  group: 'Settings page',
  name: 'Signed in · reminder + zen on',
  size: phoneSize,
  wrapper: wrapSignedIn,
)
Widget settingsPageSignedIn() => const SettingsScreen();

@Preview(
  group: 'Settings page',
  name: 'Large text (1.5×)',
  size: phoneSize,
  textScaleFactor: 1.5,
  wrapper: wrapDark,
)
Widget settingsPageLargeText() => const SettingsScreen();

@Preview(
  group: 'Settings page',
  name: 'Small phone (360×640)',
  size: Size(360, 640),
  wrapper: wrapDark,
)
Widget settingsPageSmall() => const SettingsScreen();

// ---------------------------------------------------------------------------
// Individual tiles
// ---------------------------------------------------------------------------

@Preview(
  group: 'Tiles',
  name: 'Reminder tile · off',
  size: Size(390, 200),
  wrapper: wrapDarkTile,
)
Widget reminderTileOff() => const ReminderTile();

@Preview(
  group: 'Tiles',
  name: 'Reminder tile · custom 07:30',
  size: Size(390, 200),
  wrapper: wrapConfiguredTile,
)
Widget reminderTileOn() => const ReminderTile();

@Preview(
  group: 'Tiles',
  name: 'Account · signed out',
  size: Size(390, 260),
  wrapper: wrapDarkTile,
)
Widget accountSignedOut() => const AccountSectionWidget(inCard: true);

@Preview(
  group: 'Tiles',
  name: 'Account · signed in',
  size: Size(390, 260),
  wrapper: wrapConfiguredTile,
)
Widget accountSignedIn() => const AccountSectionWidget(inCard: true);

@Preview(
  group: 'Tiles',
  name: 'Theme + App icon rows',
  size: Size(390, 220),
  wrapper: wrapDarkTile,
)
Widget themeAndIconRows() => Builder(
  builder: (context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ThemeTile(
          icon: MeditoIcon(assetName: AssetConstants.icSparks, color: color),
          title: l10n.themeTitle,
        ),
        AppIconTile(
          icon: MeditoIcon(assetName: MeditoIcons.home, color: color),
          title: l10n.appIconTitle,
          hasUnderline: false,
        ),
      ],
    );
  },
);

@Preview(
  group: 'Tiles',
  name: 'Theme + App icon rows · light',
  size: Size(390, 220),
  wrapper: wrapLightTile,
)
Widget themeAndIconRowsLight() => themeAndIconRows();

@Preview(
  group: 'Tiles',
  name: 'Zen mode + DND toggles',
  size: Size(390, 160),
  wrapper: wrapConfiguredTile,
)
Widget toggleTiles() => Builder(
  builder: (context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DndSettingTile(
          icon: MeditoIcon(assetName: MeditoIcons.moon, color: color),
          title: l10n.enableDndDuringMeditation,
          hasUnderline: true,
        ),
        ZenModeTile(
          icon: MeditoIcon(assetName: MeditoIcons.sun, color: color),
          title: l10n.zenMode,
          hasUnderline: false,
        ),
      ],
    );
  },
);

@Preview(
  group: 'Settings page',
  name: 'Advanced screen',
  size: phoneSize,
  wrapper: wrapSignedIn,
)
Widget advancedScreen() => const AdvancedSettingsScreen();

// ---------------------------------------------------------------------------
// Dialogs & sheets
// ---------------------------------------------------------------------------

@Preview(
  group: 'Dialogs',
  name: 'Reminder sheet · off',
  size: Size(390, 420),
  wrapper: wrapDark,
)
Widget reminderSheetOff() => const Align(
  alignment: Alignment.bottomCenter,
  child: Material(child: ReminderOptionsSheet(current: null, enabled: false)),
);

@Preview(
  group: 'Dialogs',
  name: 'Reminder sheet · evening selected',
  size: Size(390, 480),
  wrapper: wrapDark,
)
Widget reminderSheetEvening() => const Align(
  alignment: Alignment.bottomCenter,
  child: Material(
    child: ReminderOptionsSheet(
      current: TimeOfDay(hour: 20, minute: 0),
      enabled: true,
    ),
  ),
);

@Preview(
  group: 'Dialogs',
  name: 'Reminder sheet · custom · light',
  size: Size(390, 480),
  wrapper: wrapLight,
)
Widget reminderSheetCustomLight() => const Align(
  alignment: Alignment.bottomCenter,
  child: Material(
    child: ReminderOptionsSheet(
      current: TimeOfDay(hour: 6, minute: 45),
      enabled: true,
    ),
  ),
);

@Preview(
  group: 'Dialogs',
  name: 'Theme sheet',
  size: Size(390, 360),
  wrapper: wrapDark,
)
Widget themeSheet() => const Align(
  alignment: Alignment.bottomCenter,
  child: Material(child: ThemeSheet()),
);

@Preview(
  group: 'Dialogs',
  name: 'App icon sheet',
  size: Size(390, 560),
  wrapper: wrapDark,
)
Widget appIconSheet() => const Align(
  alignment: Alignment.bottomCenter,
  child: Material(child: AppIconSheet(current: AppIconOption.ocean)),
);

@Preview(
  group: 'Dialogs',
  name: 'Zen mode sheet · on',
  size: Size(390, 320),
  wrapper: wrapConfiguredTile,
)
Widget zenModeSheetOn() =>
    const Align(alignment: Alignment.bottomCenter, child: ZenModeSheet());

@Preview(
  group: 'Dialogs',
  name: 'Zen mode sheet · off · light',
  size: Size(390, 320),
  wrapper: wrapLightTile,
)
Widget zenModeSheetOff() =>
    const Align(alignment: Alignment.bottomCenter, child: ZenModeSheet());

@Preview(
  group: 'Dialogs',
  name: 'Day boundary offset (4h)',
  size: Size(390, 560),
  wrapper: wrapDark,
)
Widget dayBoundaryDialog() =>
    const Center(child: DayBoundaryOffsetDialog(currentHours: 4));

@Preview(
  group: 'Dialogs',
  name: 'Day boundary offset · light',
  size: Size(390, 560),
  wrapper: wrapLightTile,
)
Widget dayBoundaryDialogLight() =>
    const Center(child: DayBoundaryOffsetDialog(currentHours: 0));
