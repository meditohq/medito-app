import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/constants/theme/text_theme.dart';

import '../colors/color_constants.dart';
import 'input_theme.dart';

ThemeData appTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    splashColor: ColorConstants.ebony,
    canvasColor: ColorConstants.ebony,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: const ColorScheme.dark(
      surface: ColorConstants.ebony,
      secondary: ColorConstants.walterWhite,
    ),
    scaffoldBackgroundColor: ColorConstants.ebony,
    textTheme: meditoTextTheme(context),
    inputDecorationTheme: inputDecorationTheme(),
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        systemNavigationBarColor: ColorConstants.ebony,
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
  );
}