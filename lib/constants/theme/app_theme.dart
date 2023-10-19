import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'input_theme.dart';
import 'slide_transition_builder.dart';

ThemeData appTheme(BuildContext context) {
  return ThemeData(
    splashColor: ColorConstants.ebony,
    canvasColor: ColorConstants.ebony,
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: SlideTransitionBuilder(),
    }),
    colorScheme: ColorScheme.dark(secondary: ColorConstants.walterWhite),
    textTheme: meditoTextTheme(context),
    inputDecorationTheme: inputDecorationTheme(),
  );
}
