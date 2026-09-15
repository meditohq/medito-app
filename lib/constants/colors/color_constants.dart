import 'package:flutter/material.dart';

class ColorConstants {
  static const black = Colors.black;
  static const white = Colors.white;
  static const transparent = Colors.transparent;

  static const ebony = Color(0xFF1A1A1A);
  static const greyIsTheNewBlack = Color(0xFF171717);
  static const greyIsTheNewGrey = Color(0xFF333333);
  static const charcoal = Color(0xFF333333);
  static const softGrey = Color(0xFF404040);
  static const graphite = Color(0xFFA1A1A1);
  static const moon = Color(0xFF525252);

  // Accent. Monochrome after tickets.knit.amsterdam: the page's "primary" is a
  // light button with dark text in dark mode, and vice versa; see onAccent*.
  static const lightPurple = Color(0xFFE5E5E5);
  static const onAccentDark = Color(0xFF171717);
  static const onAccentLight = Color(0xFFFAFAFA);
  static const lightBlue = Color(0xFF5DADE2);
  static const amber = Color(0xFFFF6568);
  static const amsterdamSummer = Color(0xFF1F1F1F);
  static const onyx = Color(0xFF262626);
  static const brightSky = Color(0xFFD4EDF7);
  static const puddle = Color(0xFFD1BDA9);

  // Light theme colors
  // Accessibility notes (WCAG 2.1 AA requires 4.5:1 for normal text, 3:1 for
  // large text / non-text UI). Contrast ratios below are vs. lightSurface
  // (#FFFFFF) unless noted.
  static const lightBackground = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF5F5F5);
  static const lightOnSurface = Color(0xFF0A0A0A);
  static const lightOnBackground = Color(0xFF0A0A0A);
  // Darkened from #6B7280 (which was 4.31:1 on lightCard — sub-AA) to slate-600.
  // 7.56:1 on white, 6.74:1 on lightCard — AAA for body copy.
  static const lightSecondary = Color(0xFF737373); // 4.7:1 on white — AA
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFE5E5E5);
  static const lightSoftGrey = Color(0xFFD4D4D4);
  static const lightGraphite = Color(0xFF737373);
  // Darker variant of the brand purple for light-mode primary / text / buttons.
  // lightPurple (#917DF0) is only 3.05:1 on white — fails AA for text and for
  // white-on-purple button fills. lightPrimary is 6.35:1 with white → AA.
  static const lightPrimary = Color(0xFF171717);
  // Darker error for light surfaces (amber #EF5E55 is 3.49:1 on white — sub-AA).
  // 5.35:1 on white → AA.
  static const lightError = Color(0xFFE40014);

  static Color getColorFromString(String? name) {
    if (name == null) {
      return ColorConstants.white;
    } else {
      return Color(int.parse(name.replaceAll('#', '0xff')));
    }
  }
}

/// The brand purple, resolved per theme so the whole app shows a single purple
/// at a time:
///   * Dark mode → [ColorConstants.lightPurple] (bright #917DF0) — reads fine
///     on dark surfaces and preserves the brand accent.
///   * Light mode → [ColorConstants.lightPrimary] (darker #5D4EC0) — meets
///     WCAG AA contrast (6.35:1 with white) for text and button fills on the
///     light scaffold, and avoids the visible mismatch between themed widgets
///     (which already routed through [ColorConstants.lightPrimary]) and
///     widgets that hardcoded [ColorConstants.lightPurple].
extension BrandPurple on BuildContext {
  Color get brandPurple {
    return Theme.of(this).brightness == Brightness.dark
        ? ColorConstants.lightPurple
        : ColorConstants.lightPrimary;
  }

  /// Foreground for glyphs and text drawn on [brandPurple].
  Color get onBrandPurple {
    return Theme.of(this).brightness == Brightness.dark
        ? ColorConstants.onAccentDark
        : ColorConstants.onAccentLight;
  }
}
