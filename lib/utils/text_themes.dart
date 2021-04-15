import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/style.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

TextTheme meditoTextTheme(BuildContext context) {
  return GoogleFonts.manropeTextTheme(Theme.of(context).textTheme.copyWith(
        headline1: TextStyle(
          // greetings text
          // btm bar text selected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.5,
          color: MeditoColors.walterWhite,
        ),
        headline2: TextStyle(
          // btm bar text unselected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: MeditoColors.meditoTextGrey,
        ),
        headline3: TextStyle(
          // header of rows on homepage
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.3,
          color: MeditoColors.walterWhite,
        ),
        headline4: TextStyle(
          // packs title on home and packs screen
          // streak tile data (not title)
          // downloads tile session name
          // overflow menu
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: MeditoColors.walterWhite,
        ),
        subtitle1: TextStyle(
          // packs subtitle on home
          // downloads subtitle
          // streak/stats tile title
          fontSize: 14,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: MeditoColors.meditoTextGrey,
        ),
        subtitle2: TextStyle(
          // shortcut title
          fontSize: 14,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: MeditoColors.walterWhite,
        ),
        caption: TextStyle(
          // shortcut title
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: MeditoColors.meditoTextGrey,
        ),
        bodyText2: TextStyle(
          // shortcut title
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.normal,
          height: 1.3,
          color: MeditoColors.meditoTextGrey,
        ),
      ));
}

Map<String, Style> htmlTheme(BuildContext context) {
  return {
    'body': Style(
      textAlign: TextAlign.center
    ),
    'h1': Style(
      fontSize: FontSize(20),
      textDecoration: TextDecoration.underline,
      color: MeditoColors.walterWhite,
    ),
    'h2': Style(
      fontSize: FontSize(20),
      fontWeight: FontWeight.w600,
      color: MeditoColors.walterWhite,
    ),
    'h3': Style(
      fontSize: FontSize(18),
      color: MeditoColors.walterWhite,
    ),
    'hr': Style(
      height: 1,
      margin: const EdgeInsets.only(top: 24, bottom: 24),
      border: Border(
        bottom: BorderSide(width: 1.0, color: MeditoColors.softGrey),
      ),
    ),
    'p > a, a': Style(
        fontSize: FontSize(16),
        fontWeight: FontWeight.w600,
        color: MeditoColors.link),
    'p': Style(
      textAlign: TextAlign.start,
        fontSize: FontSize(16),
        lineHeight: 1.6,
        color: MeditoColors.walterWhite),
    'li': Style(
        fontSize: FontSize(16),
        lineHeight: 1.6,
        margin: const EdgeInsets.only(bottom: 24),
        color: MeditoColors.walterWhite),
  };
}
