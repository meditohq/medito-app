/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

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

  static const lightPurple = Color(0xFF917DF0);
  static const amsterdamSummer = Color(0xFF211F26);
  static const onyx = Color(0xFF2A2A32);

  static Color getColorFromString(String? name) {
    if (name == null) {
      return ColorConstants.white;
    } else {
      return Color(int.parse(name.replaceAll('#', '0xff')));
    }
  }
}
