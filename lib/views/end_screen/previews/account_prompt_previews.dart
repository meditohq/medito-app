// Widget previews for the end-screen account-conversion card.
//
//   flutter widget-preview start --web-server
//
// The card is a fixed-copy soft-ask, so the interesting axes are theme
// (light/dark), locale (Spanish copy is longer) and large text.

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/views/end_screen/widgets/account_prompt_card.dart';
import 'package:medito/views/previews/preview_support.dart';

void _noop() {}

/// Phone width, card height — a full 390×844 canvas is mostly empty space.
const accountPromptCardSize = Size(390, 220);

AccountPromptCard _card() =>
    AccountPromptCard(onSave: _noop, onSnooze: _noop, onDismiss: _noop);

Widget wrapDark(Widget child) => PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget wrapEs(Widget child) =>
    PreviewShell(prefs: prefsDark, locale: const Locale('es'), child: child);

@Preview(
  group: 'Account prompt',
  name: '390×844 · dark',
  size: accountPromptCardSize,
  wrapper: wrapDark,
)
Widget accountPromptDark() => _card();

@Preview(
  group: 'Account prompt',
  name: '390×844 · light',
  size: accountPromptCardSize,
  wrapper: wrapLight,
)
Widget accountPromptLight() => _card();

@Preview(
  group: 'Account prompt',
  name: 'Spanish · dark',
  size: accountPromptCardSize,
  wrapper: wrapEs,
)
Widget accountPromptEs() => _card();

@Preview(
  group: 'Account prompt',
  name: 'Large text 1.4× · dark',
  size: accountPromptCardSize,
  textScaleFactor: 1.4,
  wrapper: wrapDark,
)
Widget accountPromptLargeText() => _card();
