import 'package:Medito/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

var _borderRadiusSmall = BorderRadius.circular(13);
var _borderRadiusLarge = BorderRadius.circular(16);
var _paddingSmall = 8.0;
var _paddingLarge = 12.0;

Text getTextLabel(String label, int i, int startNumber, BuildContext context) {
  return Text(label,
      style: i == startNumber
          ? Theme.of(context).textTheme.display2
          : Theme.of(context).textTheme.display1);
}

BoxDecoration getBoxDecoration(int i, int startNumber, {Color color}) {

  if (color == null) {
    color = i == startNumber ? MeditoColors.darkColor : MeditoColors.lightColor;
  }

  return BoxDecoration(
    color: color,
    borderRadius: i == startNumber ? _borderRadiusSmall : _borderRadiusLarge,
  );
}

EdgeInsets getEdgeInsets(int i, int startNumber) {
  return EdgeInsets.only(top: 8, bottom: 8, left: 12, right: 12);
}

getLoremMedium() {
  return 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper. ';
}

getLoremLong() {
  return 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mattis pulvinar magna, non consectetur ante laoreet quis. Praesent consectetur vel quam eu iaculis. Curabitur vitae hendrerit magna, id aliquet erat. Aenean sit amet libero non tellus porta euismod. Curabitur tincidunt mi sed sem volutpat, sed bibendum eros viverra. Cras ac ipsum eu justo vestibulum tincidunt. Quisque augue mi, fringilla vitae dui eu, tristique fermentum orci. Aenean commodo ullamcorper magna, eu finibus dolor sollicitudin quis. Ut placerat tortor aliquet felis mattis gravida. Curabitur lacinia venenatis ullamcorper.';
}

getLoremShort() {
  return 'Lorem ipsum dolor';
}
