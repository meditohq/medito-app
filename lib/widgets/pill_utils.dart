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

import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

var _borderRadiusSmall = BorderRadius.circular(13);
var _borderRadiusLarge = BorderRadius.circular(16);

Text getTextLabel(String label, int i, int startNumber, BuildContext context) {
  return Text(label,
      style: i == startNumber
          ? Theme.of(context).textTheme.headline3
          : Theme.of(context).textTheme.headline4);
}

//todo these methods have useless parameters. get rid!
BoxDecoration getBoxDecoration(int i, int startNumber, {Color color}) {
  color ??= i == startNumber ? MeditoColors.darkColor : MeditoColors.walterWhite;

  return BoxDecoration(
    color: color,
    borderRadius: i == startNumber ? _borderRadiusSmall : _borderRadiusLarge,
  );
}

EdgeInsets getEdgeInsets(int i, int startNumber) {
  return EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12);
}

String getLoremMedium() {
  return 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper. ';
}

String getLoremLong() {
  return 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.';
}

String getLoremShort() {
  return 'Lorem ipsum dolor';
}
