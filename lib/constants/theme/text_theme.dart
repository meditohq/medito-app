import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../constants.dart';

TextTheme meditoTextTheme(BuildContext context, [ThemeMode? themeMode]) {
  final brightness = MediaQuery.of(context).platformBrightness;
  final isDark =
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && brightness == Brightness.dark);

  return Theme.of(context).textTheme.copyWith(
    displayLarge: TextStyle(
      // greetings text
      // btm bar text selected
      fontSize: 18,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w800,
      height: 1.5,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    displayMedium: TextStyle(
      // btm bar text unselected
      fontSize: 18,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w700,
      height: 1.5,
      color: isDark ? ColorConstants.graphite : ColorConstants.lightGraphite,
      fontFamily: dmSans,
    ),
    displaySmall: TextStyle(
      // header of rows on homepage
      fontSize: 18,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w800,
      height: 1.3,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    headlineMedium: TextStyle(
      // packs title on home and packs screen
      // streak tile data (not title)
      // downloads tile session name
      // overflow menu
      fontSize: 16,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    headlineSmall: TextStyle(
      // stats widget
      fontSize: 20,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w700,
      height: 1.2,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    titleMedium: TextStyle(
      // packs subtitle on home
      // downloads subtitle
      fontSize: 14,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: isDark ? ColorConstants.graphite : ColorConstants.lightGraphite,
      fontFamily: dmSans,
    ),
    titleSmall: TextStyle(
      // shortcut title
      fontSize: 14,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    bodySmall: TextStyle(
      // shortcut title
      fontSize: 12,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: isDark ? ColorConstants.graphite : ColorConstants.lightGraphite,
      fontFamily: dmSans,
    ),
    bodyMedium: TextStyle(
      // error widget
      fontSize: 16,
      letterSpacing: 0.5,
      fontWeight: FontWeight.normal,
      height: 1.3,
      color: isDark ? ColorConstants.graphite : ColorConstants.lightGraphite,
      fontFamily: dmSans,
    ),
    bodyLarge: TextStyle(
      // daily text and quote
      fontSize: 14,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    titleLarge: TextStyle(
      // onboarding option button label
      fontSize: 16,
      letterSpacing: 0.2,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    labelLarge: TextStyle(
      // shortcut title
      fontSize: 20,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    labelMedium: TextStyle(
      // error widget
      fontSize: 16,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
      height: 1.3,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
    labelSmall: TextStyle(
      // daily text and quote
      fontSize: 14,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
      fontFamily: dmSans,
    ),
  );
}

MarkdownStyleSheet buildMarkdownStyleSheet(BuildContext context) {
  return MarkdownStyleSheet.fromTheme(Theme.of(context));
}
