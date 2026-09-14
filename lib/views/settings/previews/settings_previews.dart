// Widget previews for the Settings page.
//
// Run from the project root:
//
//   flutter widget-preview start --web-server
//
// and open the printed URL. Previews render the REAL widgets through the
// shared [PreviewShell] (in-memory SharedPreferences + fake AuthRepository),
// so no backend, Firebase or device is needed. Edits hot-reload.
//
// Reference: https://flutter.dev/to/widget-previews

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/settings/settings_screen.dart';
import 'package:medito/views/settings/widgets/account_section_widget.dart';
import 'package:medito/views/settings/advanced_settings_screen.dart';
import 'package:medito/views/settings/widgets/app_icon_tile.dart';
import 'package:medito/views/settings/widgets/app_icon_option.dart';
import 'package:medito/views/settings/widgets/day_boundary_offset_dialog.dart';
import 'package:medito/views/settings/widgets/dnd_setting_tile.dart';
import 'package:medito/views/settings/widgets/reminder_tile.dart';
import 'package:medito/views/settings/widgets/theme_tile.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/settings/widgets/zen_mode_tile.dart';
import 'package:medito/widgets/medito_icon.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// Reminder + zen on, for the configured-tile states.
const Map<String, Object> prefsReminderOn = {
  SharedPreferenceConstants.themePreference: 'dark',
  SharedPreferenceConstants.savedHours: 7,
  SharedPreferenceConstants.savedMinutes: 30,
  SharedPreferenceConstants.dailyReminderEnabled: true,
  SharedPreferenceConstants.zenModeEnabled: true,
  SharedPreferenceConstants.dayBoundaryOffsetHours: 4,
};

// Wrappers must be top-level functions so they can be referenced from a
// const annotation.
Widget wrapDark(Widget child) => PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget wrapSignedIn(Widget child) => PreviewShell(
  prefs: prefsReminderOn,
  email: 'preview@example.com',
  child: child,
);

Widget wrapDarkTile(Widget child) =>
    PreviewShell(prefs: prefsDark, padded: true, child: child);

Widget wrapLightTile(Widget child) => PreviewShell(
  prefs: prefsLight,
  themeMode: ThemeMode.light,
  padded: true,
  child: child,
);

Widget wrapConfiguredTile(Widget child) => PreviewShell(
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
