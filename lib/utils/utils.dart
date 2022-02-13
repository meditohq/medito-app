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

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/user/user_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

Widget getNetworkImageWidget(String url,
    {Color svgColor, double startHeight = 0.0}) {
  final headers = {HttpHeaders.authorizationHeader: CONTENT_TOKEN};
  return CachedNetworkImage(
    fit: BoxFit.fill,
    httpHeaders: headers,
    imageUrl: url ?? '',
  );
}

Future<bool> checkConnectivity() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  return connectivityResult != ConnectivityResult.none;
}

Color parseColor(String color) {
  if (color == null || color.isEmpty) return MeditoColors.midnight;

  return Color(int.parse(color?.replaceFirst('#', 'FF'), radix: 16));
}

void createSnackBar(String message, BuildContext context,
    {Color color = Colors.red}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: color,
    duration: Duration(seconds: 6),
  );

  // Find the Scaffold in the Widget tree and use it to show a SnackBar!
  try {
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    print(e);
  }
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

Future<void> launchUrl(String href) async {
  var prefs = await SharedPreferences.getInstance();
  var userId = prefs.getString(USER_ID);
  href = href.replaceAll('{{user_id}}', userId);

  if (href.startsWith('mailto')) {
    _launchEmailSubmission(href);
  } else {
    return await canLaunch(href)
        ? await launch(href)
        : throw 'Could not launch $href';
  }
}

void _launchEmailSubmission(String href) async {
  var version;
  try {
    var packageInfo = await PackageInfo.fromPlatform();
    version = packageInfo.buildNumber;
  } catch (e) {
    print(e);
  }

  var prefs = await SharedPreferences.getInstance();
  var userId = prefs.getString(USER_ID);
  var info =
      '--- Please write email below this line v$version, id:$userId ----';

  final params = Uri(
      scheme: 'mailto',
      path: href.replaceAll('mailto:', ''),
      query: 'body=$info');

  var url = params.toString();
  if (await canLaunch(url)) {
    await launch(url);
  } else {
    print('Could not launch $url');
  }
}

Future<void> acceptTracking() async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setBool('tracking', true);
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

extension AssetUrl on String {
  String toAssetUrl() {
    return '${BASE_URL}assets/$this?download';
  }
}
