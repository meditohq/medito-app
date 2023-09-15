import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

InputDecorationTheme inputDecorationTheme() {
  var outlineInputBorder = _outlineInputBorder();

  return InputDecorationTheme(
    labelStyle: TextStyle(
      fontSize: 14.0,
      fontStyle: FontStyle.normal,
      color: ColorConstants.walterWhite,
      fontFamily: DmSans,
    ),
    floatingLabelStyle: TextStyle(
      fontSize: 15.0,
      fontStyle: FontStyle.normal,
      color: ColorConstants.walterWhite,
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
