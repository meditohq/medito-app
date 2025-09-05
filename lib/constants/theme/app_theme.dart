import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/theme/text_theme.dart';

import '../colors/color_constants.dart';
import '../styles/widget_styles.dart';
import 'input_theme.dart';

ThemeData appTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    splashColor: ColorConstants.ebony,
    cardColor: ColorConstants.onyx,
    canvasColor: ColorConstants.ebony,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme.dark(
      primary: ColorConstants.lightPurple,
      onPrimary: ColorConstants.white,
      secondary: ColorConstants.white,
      onSecondary: ColorConstants.black,
      surface: ColorConstants.ebony,
      onSurface: ColorConstants.white,
      background: ColorConstants.black,
      onBackground: ColorConstants.white,
      error: ColorConstants.amber,
      onError: ColorConstants.white,
    ),
    scaffoldBackgroundColor: ColorConstants.ebony,
    textTheme: meditoTextTheme(context),
    inputDecorationTheme: inputDecorationTheme(),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: ColorConstants.ebony,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: ColorConstants.transparent,
        statusBarIconBrightness: Brightness.light,
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
        backgroundColor: ColorConstants.black,
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
      backgroundColor: ColorConstants.ebony,
      titleTextStyle: const TextStyle(
        color: ColorConstants.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        fontFamily: dmSans,
      ),
      contentTextStyle: const TextStyle(
        color: ColorConstants.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        fontFamily: dmSans,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    // Bottom sheet theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: ColorConstants.onyx,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(14),
        ),
      ),
    ),
    // Card theme
    cardTheme: CardThemeData(
      color: ColorConstants.onyx,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
    ),
    // Switch theme
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return ColorConstants.lightPurple;
        }
        return ColorConstants.greyIsTheNewGrey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return ColorConstants.lightPurple.withOpacity(0.3);
        }
        return ColorConstants.greyIsTheNewGrey;
      }),
    ),
    // Progress indicator theme
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: ColorConstants.lightPurple,
      linearTrackColor: ColorConstants.greyIsTheNewGrey,
      circularTrackColor: ColorConstants.greyIsTheNewGrey,
    ),
  );
}
