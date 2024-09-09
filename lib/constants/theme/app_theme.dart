import 'package:flutter/material.dart';
import 'package:medito/constants/theme/text_theme.dart';

import '../colors/color_constants.dart';
import 'input_theme.dart';

ThemeData appTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    splashColor: ColorConstants.ebony,
    canvasColor: ColorConstants.ebony,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    colorScheme: ColorScheme.dark(
      surface: ColorConstants.ebony,
      secondary: ColorConstants.walterWhite,
    ),
    textTheme: meditoTextTheme(context),
    inputDecorationTheme: inputDecorationTheme(),
  );
}
