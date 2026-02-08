import 'package:flutter/material.dart';

class ColorConstants {
  static const black = Colors.black;
  static const white = Colors.white;
  static const transparent = Colors.transparent;

  static const ebony = Color(0xFF171718);
  static const greyIsTheNewBlack = Color(0xFF1C1C1E);
  static const greyIsTheNewGrey = Color(0xFF2C2C2E);
  static const charcoal = Color(0xFF303031);
  static const softGrey = Color(0xFF424345);
  static const graphite = Color(0xFFAAAAAA);
  static const moon = Color(0xFF4F4F66);

  static const lightPurple = Color(0xFF917DF0);
  static const lightBlue = Color(0xFF5DADE2);
  static const amber = Color(0xffef5e55);
  static const amsterdamSummer = Color(0xFF211F26);
  static const onyx = Color(0xFF2A2A32);
  static const brightSky = Color(0xFFD4EDF7);
  static const puddle = Color(0xFFD1BDA9);

  // Light theme colors
  static const lightBackground = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFF1F3F4);
  static const lightOnSurface = Color(0xFF1A1A1A);
  static const lightOnBackground = Color(0xFF1A1A1A);
  static const lightSecondary = Color(0xFF6B7280);
  static const lightOnSecondary = Color(0xFFFFFFFF);
  static const lightGrey = Color(0xFFE5E7EB);
  static const lightSoftGrey = Color(0xFFD1D5DB);
  static const lightGraphite = Color(0xFF6B7280);

  static Color getColorFromString(String? name) {
    if (name == null) {
      return ColorConstants.white;
    } else {
      return Color(int.parse(name.replaceAll('#', '0xff')));
    }
  }
}
