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
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

TextTheme buildDMSansTextTheme(BuildContext context) {
  return GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme.copyWith(
        headline6: TextStyle(
            fontSize: 20.0,
            height: 1.4,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.w500),
        headline5: TextStyle(
            //h2
            height: 1.4,
            fontSize: 20.0,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.w600),
        subtitle1: TextStyle(
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.lightTextColor,
            fontWeight: FontWeight.normal),
        headline4: TextStyle(
            //pill big
            height: 1.4,
            fontSize: 18.0,
            color: MeditoColors.darkBGColor,
            fontWeight: FontWeight.normal),
        headline3: TextStyle(
            //pill small
            fontSize: 14.0,
            height: 1.25,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.normal),
        headline2: TextStyle(
          //this is for bottom sheet text
          letterSpacing: 0.1,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
          color: MeditoColors.walterWhite,
        ),
        bodyText2: TextStyle(
            //this is for 'text'
            fontSize: 16.0,
            height: 1.4,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.normal),
        subtitle2: TextStyle(
            //this is for 'h3' markdown
            fontSize: 18.0,
            height: 1.4,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.normal),
        headline1: TextStyle(
            //bottom sheet filter chip
            //horizontal announcement
            fontSize: 16.0,
            height: 1.25,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.w400),
        caption: TextStyle(
            //attr widget
            fontSize: 14.0,
            height: 1.4,
            color: MeditoColors.walterWhite,
            fontWeight: FontWeight.w400),
        bodyText1: TextStyle(
            //for 'MORE DETAILS'
            // fontSize: 14.0,
            // height: 1.4,
            // color: MeditoColors.walterWhite,
            letterSpacing: 0.2,
            height: 1.5,
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w600),
      ));
}

Widget getNetworkImageWidget(String url,
    {Color svgColor, double startHeight = 0.0}) {
  if (url == null) return Container();
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
    imageUrl: url,
  );
}

Future<bool> checkConnectivity() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return true;
    }
  } on SocketException catch (_) {
    return false;
  }
  return false;
}

int getColorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF' + hexColor;
  }
  return int.parse(hexColor, radix: 16);
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

void launchDonatePage() {
  launch('https://meditofoundation.org/donate');
}

// ignore: always_declare_return_types
launchUrl(String url) async {
  await launch(url);
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
