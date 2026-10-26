// Widget previews for post-meditation mood feedback.
//
//   flutter widget-preview start --web-server

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/views/end_screen/widgets/feedback_widget.dart';
import 'package:medito/views/previews/preview_support.dart';

const ratingAskSize = Size(390, 300);

Widget _ask() =>
    const Padding(padding: EdgeInsets.all(16), child: FeedbackWidget());

Widget wrapDark(Widget child) => PreviewShell(prefs: prefsDark, child: child);

Widget wrapLight(Widget child) =>
    PreviewShell(prefs: prefsLight, themeMode: ThemeMode.light, child: child);

Widget wrapEs(Widget child) =>
    PreviewShell(prefs: prefsDark, locale: const Locale('es'), child: child);

@Preview(
  group: 'Mood feedback',
  name: 'dark',
  size: ratingAskSize,
  wrapper: wrapDark,
)
Widget ratingAskDark() => _ask();

@Preview(
  group: 'Mood feedback',
  name: 'light',
  size: ratingAskSize,
  wrapper: wrapLight,
)
Widget ratingAskLight() => _ask();

@Preview(
  group: 'Mood feedback',
  name: 'Spanish · dark',
  size: ratingAskSize,
  wrapper: wrapEs,
)
Widget ratingAskEs() => _ask();

@Preview(
  group: 'Mood feedback',
  name: 'before the 😊 tap · dark',
  size: ratingAskSize,
  wrapper: wrapDark,
)
Widget ratingAskBeforeTap() =>
    const Padding(padding: EdgeInsets.all(16), child: FeedbackWidget());
