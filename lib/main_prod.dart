import 'package:flutter/material.dart';
import 'package:flutter_flavor/flutter_flavor.dart';
import 'main_common.dart';

void main() {
  FlavorConfig(
    name: "prod",
    color: Colors.green,
    location: BannerLocation.topStart,
    variables: {
      "baseUrl": "https://api.example.com",
    },
  );
  mainCommon();
}
