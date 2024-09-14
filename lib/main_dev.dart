import 'package:flutter/material.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:medito/constants/colors/color_constants.dart';
import 'main.dart';

void main() {
  FlavorConfig(
    name: 'DEV',
    color: ColorConstants.lightPurple,
    location: BannerLocation.topEnd,
  );

  mainCommon();
}
