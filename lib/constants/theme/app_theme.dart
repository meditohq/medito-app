import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/theme/text_theme.dart';

import '../colors/color_constants.dart';
import '../styles/widget_styles.dart';
import 'input_theme.dart';

ThemeData appTheme(BuildContext context, [ThemeMode? themeMode]) {
  final brightness = MediaQuery.of(context).platformBrightness;
  final isDark = themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system && brightness == Brightness.dark);

  return ThemeData(
    useMaterial3: true,
    brightness: isDark ? Brightness.dark : Brightness.light,
    splashColor: isDark ? ColorConstants.ebony : ColorConstants.lightSurface,
    cardColor: isDark ? ColorConstants.onyx : ColorConstants.lightCard,
    canvasColor: isDark ? ColorConstants.ebony : ColorConstants.lightBackground,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: isDark
        ? const ColorScheme.dark(
            primary: ColorConstants.lightPurple,
            onPrimary: ColorConstants.white,
            secondary: ColorConstants.white,
            onSecondary: ColorConstants.black,
            surface: ColorConstants.ebony,
            onSurface: ColorConstants.white,
            error: ColorConstants.amber,
            onError: ColorConstants.white,
          )
        : const ColorScheme.light(
            primary: ColorConstants.lightPurple,
            onPrimary: ColorConstants.white,
            secondary: ColorConstants.lightSecondary,
            onSecondary: ColorConstants.lightOnSecondary,
            surface: ColorConstants.lightSurface,
            onSurface: ColorConstants.lightOnSurface,
            error: ColorConstants.amber,
            onError: ColorConstants.white,
          ),
    scaffoldBackgroundColor:
        isDark ? ColorConstants.ebony : ColorConstants.lightBackground,
    textTheme: meditoTextTheme(context),
    inputDecorationTheme: inputDecorationTheme(),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor:
            isDark ? ColorConstants.ebony : ColorConstants.lightBackground,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarColor: ColorConstants.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    ),
    // Enhanced button themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorConstants.lightPurple,
        foregroundColor: ColorConstants.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: dmSans,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor:
            isDark ? ColorConstants.black : ColorConstants.lightSurface,
        foregroundColor: ColorConstants.lightPurple,
        side: const BorderSide(color: ColorConstants.lightPurple),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: dmSans,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ColorConstants.lightPurple,
        textStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          fontFamily: dmSans,
        ),
      ),
    ),
    // Dialog theme
    dialogTheme: DialogThemeData(
      backgroundColor:
          isDark ? ColorConstants.ebony : ColorConstants.lightSurface,
      titleTextStyle: TextStyle(
        color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: dmSans,
      ),
      contentTextStyle: TextStyle(
        color: isDark ? ColorConstants.white : ColorConstants.lightOnSurface,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: dmSans,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    // Bottom sheet theme
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? ColorConstants.onyx : ColorConstants.lightCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
    ),
    // Card theme
    cardTheme: CardThemeData(
      color: isDark ? ColorConstants.onyx : ColorConstants.lightCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
    ),
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorConstants.lightPurple;
        }
        return isDark
            ? ColorConstants.greyIsTheNewGrey
            : ColorConstants.lightGrey;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return ColorConstants.lightPurple.withValues(alpha: 0.3);
        }
        return isDark
            ? ColorConstants.greyIsTheNewGrey
            : ColorConstants.lightGrey;
      }),
    ),
    // Progress indicator theme
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: ColorConstants.lightPurple,
      linearTrackColor:
          isDark ? ColorConstants.greyIsTheNewGrey : ColorConstants.lightGrey,
      circularTrackColor:
          isDark ? ColorConstants.greyIsTheNewGrey : ColorConstants.lightGrey,
    ),
  );
}
