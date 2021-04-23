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

import 'dart:io';

import 'package:Medito/utils/colors.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Widget getNetworkImageWidget(String url,
    {Color svgColor, double startHeight = 0.0}) {
  final headers = {HttpHeaders.authorizationHeader: basicAuth};
  return CachedNetworkImage(
    fit: BoxFit.fill,
    errorWidget: (
      context,
      url,
      error,
    ) =>
        Icon(
      Icons.broken_image_outlined,
      color: MeditoColors.walterWhiteTrans,
    ),
    httpHeaders: headers,
    placeholder: (context, url) => Container(
      height: startHeight,
    ),
    imageUrl: url ?? '',
  );
}

Future<bool> checkConnectivity() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.mobile) {
    return true;
  } else if (connectivityResult == ConnectivityResult.wifi) {
    return true;
  }
  return false;
}

Color parseColor(String color) {
  if (color == null || color.isEmpty) return MeditoColors.midnight;

  return Color(int.parse(color?.replaceFirst('#', 'FF'), radix: 16));
}

void createSnackBar(String message, BuildContext context) {
  final snackBar =
      SnackBar(content: Text(message), backgroundColor: Colors.red);

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

void createSnackBarWithColor(
    String message, BuildContext context, Color color) {
  final snackBar = SnackBar(
      content: Text(message,
          style: Theme.of(context)
              .textTheme
              .caption
              .copyWith(color: MeditoColors.almostBlack)),
      backgroundColor: color);

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

bool isDayBefore(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day - 1;
}

// ignore: always_declare_return_types
Future<bool> launchUrl(String url) async {
  return launch(url);
}

Future<void> acceptTracking() async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tracking', true);
}

Future<bool> isTrackingAccepted() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getBool('tracking') ?? false;
}

Future<void> trackingAnswered() async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setBool('trackingAnswered', true);
}

Future<bool> getTrackingAnswered() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getBool('trackingAnswered') ?? false;
}

extension EmptyOrNull on String {
  bool isEmptyOrNull() {
    if (this == null) return true;
    if (isEmpty) return true;
    return false;
  }

  bool isNotEmptyAndNotNull() {
    if (this != null && isNotEmpty) return true;
    return false;
  }
}
