import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

TextTheme meditoTextTheme(BuildContext context) {
  return Theme.of(context).textTheme.copyWith(
        displayLarge: TextStyle(
          // greetings text
          // btm bar text selected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.5,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        displayMedium: TextStyle(
          // btm bar text unselected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: DmSans,
        ),
        displaySmall: TextStyle(
          // header of rows on homepage
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.3,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
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
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        headlineSmall: TextStyle(
          // stats widget
          fontSize: 20,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        titleMedium: TextStyle(
          // packs subtitle on home
          // downloads subtitle
          fontSize: 14,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: DmSans,
        ),
        titleSmall: TextStyle(
          // shortcut title
          fontSize: 14,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        bodySmall: TextStyle(
          // shortcut title
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: DmSans,
        ),
        bodyMedium: TextStyle(
          // error widget
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.normal,
          height: 1.3,
          color: ColorConstants.graphite,
          fontFamily: DmSans,
        ),
        bodyLarge: TextStyle(
          // daily text and quote
          fontSize: 14,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        labelLarge: TextStyle(
          // shortcut title
          fontSize: 20,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        labelMedium: TextStyle(
          // error widget
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
        labelSmall: TextStyle(
          // daily text and quote
          fontSize: 14,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: ColorConstants.walterWhite,
          fontFamily: DmSans,
        ),
      );
}

MarkdownStyleSheet buildMarkdownStyleSheet(BuildContext context) {
  return MarkdownStyleSheet.fromTheme(Theme.of(context));
}
