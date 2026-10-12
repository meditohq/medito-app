// Widget previews for the end-screen usage-stats re-consent card.
//
//   flutter widget-preview start --web-server
//
// Fixed copy with two equal buttons, so the axes are theme, locale (German
// and Spanish buttons are longer) and large text.

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:medito/views/end_screen/previews/account_prompt_previews.dart'
    show wrapDark, wrapLight, wrapEs;
import 'package:medito/views/end_screen/widgets/analytics_reconsent_card.dart';
import 'package:medito/views/previews/preview_support.dart';

void _noop() {}

/// Phone width; the body is longer than the other soft-asks'.
const analyticsReconsentCardSize = Size(390, 340);

AnalyticsReconsentCard _card() =>
    const AnalyticsReconsentCard(onAccept: _noop, onDecline: _noop);

Widget wrapDe(Widget child) =>
    PreviewShell(prefs: prefsDark, locale: const Locale('de'), child: child);

@Preview(
  group: 'Analytics re-consent',
  name: '390 · dark',
  size: analyticsReconsentCardSize,
  wrapper: wrapDark,
)
Widget analyticsReconsentDark() => _card();

@Preview(
  group: 'Analytics re-consent',
  name: '390 · light',
  size: analyticsReconsentCardSize,
  wrapper: wrapLight,
)
Widget analyticsReconsentLight() => _card();

@Preview(
  group: 'Analytics re-consent',
  name: 'Spanish · dark',
  size: analyticsReconsentCardSize,
  wrapper: wrapEs,
)
Widget analyticsReconsentEs() => _card();

@Preview(
  group: 'Analytics re-consent',
  name: 'German · dark',
  size: Size(390, 380),
  wrapper: wrapDe,
)
Widget analyticsReconsentDe() => _card();

@Preview(
  group: 'Analytics re-consent',
  name: 'Large text 1.4× · dark',
  size: Size(390, 460),
  textScaleFactor: 1.4,
  wrapper: wrapDark,
)
Widget analyticsReconsentLargeText() => _card();
