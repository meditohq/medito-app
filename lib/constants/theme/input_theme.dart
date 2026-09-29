import 'package:flutter/material.dart';

import '../constants.dart';

InputDecorationTheme inputDecorationTheme() {
  var outlineInputBorder = _outlineInputBorder();

  return InputDecorationTheme(
    labelStyle: const TextStyle(
      fontSize: 14,
      fontStyle: FontStyle.normal,
      color: ColorConstants.white,
      fontFamily: googleSans,
    ),
    enabledBorder: outlineInputBorder,
    focusedBorder: outlineInputBorder,
    border: outlineInputBorder,
    filled: true,
    fillColor: ColorConstants.onyx,
  );
}

OutlineInputBorder _outlineInputBorder({Color color = ColorConstants.onyx}) =>
    OutlineInputBorder(
      borderSide: BorderSide(color: color, width: 0),
      borderRadius: BorderRadius.circular(40),
    );
