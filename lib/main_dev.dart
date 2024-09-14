import 'package:flutter/material.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'main_common.dart';

void main() {
  FlavorConfig(
    name: 'DEV',
    color: Colors.red,
    location: BannerLocation.topEnd,
    variables: {
      "baseUrl": "https://dev-api.example.com",
    },
  );

  mainCommon();
}