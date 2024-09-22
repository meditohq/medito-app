import 'package:flutter/material.dart';

import '../constants.dart';

InputDecorationTheme inputDecorationTheme() {
  var outlineInputBorder = _outlineInputBorder();

  return InputDecorationTheme(
    labelStyle: const TextStyle(
      fontSize: 14.0,
      fontStyle: FontStyle.normal,
      color: ColorConstants.white,
      fontFamily: DmSans,
    ),
    floatingLabelStyle: const TextStyle(
      fontSize: 15.0,
      fontStyle: FontStyle.normal,
      color: ColorConstants.white,
      fontFamily: DmSans,
    ),
    enabledBorder: outlineInputBorder,
    focusedBorder: outlineInputBorder,
    border: outlineInputBorder,
    filled: true,
    fillColor: ColorConstants.onyx,
  );
}

OutlineInputBorder _outlineInputBorder({
  Color color = ColorConstants.onyx,
}) =>
    OutlineInputBorder(
      borderSide: BorderSide(color: color, width: 0),
      borderRadius: BorderRadius.circular(40),
    );
