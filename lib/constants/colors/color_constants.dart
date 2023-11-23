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
  static const greyIsTheNewBlack = Color(0xFF1C1C1E);
  static const greyIsTheNewGrey = Color(0xFF2C2C2E);

  // V2
  static const transparent = Color(0x00ffffff);
  static const walterWhite = Colors.white;
  static const softGrey = Color(0xff424345);
  static const quiteGrey = Color(0xffD5D3D1);
  static const lightPurple = Color(0xff9D8CF2);
  static const onyx = Color(0xff2A2A32);
  static const ebony = Color(0xff171718);
  static const graphite = Color(0xffAAAAAA);
  static const charcoal = Color(0xff303031);
  static const nearWhite = Color(0xffFEFEFE);

  static Color getColorFromString(String name) {
    var color = int.parse(name.replaceAll('#', '0xff'));

    return Color(color);
  }
}
