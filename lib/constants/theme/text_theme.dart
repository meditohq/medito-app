import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../constants.dart';

TextTheme meditoTextTheme(BuildContext context) {
  return Theme.of(context).textTheme.copyWith(
        displayLarge: const TextStyle(
          // greetings text
          // btm bar text selected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.5,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        displayMedium: const TextStyle(
          // btm bar text unselected
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: dmSans,
        ),
        displaySmall: const TextStyle(
          // header of rows on homepage
          fontSize: 18,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w800,
          height: 1.3,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        headlineMedium: const TextStyle(
          // packs title on home and packs screen
          // streak tile data (not title)
          // downloads tile session name
          // overflow menu
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        headlineSmall: const TextStyle(
          // stats widget
          fontSize: 20,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        titleMedium: const TextStyle(
          // packs subtitle on home
          // downloads subtitle
          fontSize: 14,
          letterSpacing: 0.4,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: dmSans,
        ),
        titleSmall: const TextStyle(
          // shortcut title
          fontSize: 14,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        bodySmall: const TextStyle(
          // shortcut title
          fontSize: 12,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: ColorConstants.graphite,
          fontFamily: dmSans,
        ),
        bodyMedium: const TextStyle(
          // error widget
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.normal,
          height: 1.3,
          color: ColorConstants.graphite,
          fontFamily: dmSans,
        ),
        bodyLarge: const TextStyle(
          // daily text and quote
          fontSize: 14,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        labelLarge: const TextStyle(
          // shortcut title
          fontSize: 20,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          height: 1.5,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        labelMedium: const TextStyle(
          // error widget
          fontSize: 16,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
        labelSmall: const TextStyle(
          // daily text and quote
          fontSize: 14,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: ColorConstants.white,
          fontFamily: dmSans,
        ),
      );
}

MarkdownStyleSheet buildMarkdownStyleSheet(BuildContext context) {
  return MarkdownStyleSheet.fromTheme(Theme.of(context));
}
