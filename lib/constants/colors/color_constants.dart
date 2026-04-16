import 'package:flutter/material.dart';

class ColorConstants {
  static const black = Colors.black;
  static const white = Colors.white;
  static const transparent = Colors.transparent;

  static const ebony = Color(0xFF171718);
  static const greyIsTheNewBlack = Color(0xFF1C1C1E);
  static const greyIsTheNewGrey = Color(0xFF2C2C2E);
  static const charcoal = Color(0xFF303031);
  static const softGrey = Color(0xFF424345);
  static const graphite = Color(0xFFAAAAAA);
  static const moon = Color(0xFF4F4F66);

  static const lightPurple = Color(0xFF917DF0);
  static const lightBlue = Color(0xFF5DADE2);
  static const amber = Color(0xffef5e55);
  static const amsterdamSummer = Color(0xFF211F26);
  static const onyx = Color(0xFF2A2A32);
  static const brightSky = Color(0xFFD4EDF7);
  static const puddle = Color(0xFFD1BDA9);

  // Light theme colors
  // Accessibility notes (WCAG 2.1 AA requires 4.5:1 for normal text, 3:1 for
  // large text / non-text UI). Contrast ratios below are vs. lightSurface
  // (#FFFFFF) unless noted.
  static const lightBackground = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF1F3F4);
  static const lightOnSurface = Color(0xFF1A1A1A); // 17.4:1 on white — AAA
  static const lightOnBackground = Color(0xFF1A1A1A);
  // Darkened from #6B7280 (which was 4.31:1 on lightCard — sub-AA) to slate-600.
  // 7.56:1 on white, 6.74:1 on lightCard — AAA for body copy.
  static const lightSecondary = Color(0xFF4B5563);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFE5E7EB);
  static const lightSoftGrey = Color(0xFFD1D5DB);
  static const lightGraphite = Color(0xFF4B5563);
  // Darker variant of the brand purple for light-mode primary / text / buttons.
  // lightPurple (#917DF0) is only 3.05:1 on white — fails AA for text and for
  // white-on-purple button fills. lightPrimary is 6.35:1 with white → AA.
  static const lightPrimary = Color(0xFF5D4EC0);
  // Darker error for light surfaces (amber #EF5E55 is 3.49:1 on white — sub-AA).
  // 5.35:1 on white → AA.
  static const lightError = Color(0xFFC4332B);

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
}
