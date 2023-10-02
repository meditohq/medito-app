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
import 'dart:typed_data';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/user_utils.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

Future<bool> checkConnectivity() async {
  var connectivityResult = await Connectivity().checkConnectivity();

  return connectivityResult != ConnectivityResult.none;
}

Color parseColor(String? color) {
  if (color == null || color.isEmpty) return ColorConstants.midnight;

  return Color(int.parse(color.replaceFirst('#', 'FF'), radix: 16));
}

void createSnackBar(
  String message,
  BuildContext context, {
  Color color = Colors.red,
}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: color,
    duration: Duration(seconds: 6),
  );

  try {
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    print(e);
  }
}

bool isDayBefore(DateTime day1, DateTime day2) {
  return day1.year == day2.year &&
      day1.month == day2.month &&
      day1.day == day2.day - 1;
}

Future<bool> launchUrlMedito(String? href) async {
  var prefs = await SharedPreferences.getInstance();
  var userId = prefs.getString(USER_ID);
  if (userId != null) {
    href = href?.replaceAll('{{user_id}}', userId);
  }

  if (href != null && href.startsWith('mailto')) {
    var version = await getDeviceInfoString();
    var userId = prefs.getString(USER_ID);
    var info =
        '--- Please write email below this line $version, id:$userId ----';

    await launchEmailSubmission(href, body: info);

    return true;
  } else if (href != null) {
    final params = Uri(
      path: href.replaceAll('mailto:', ''),
    );

    return await canLaunchUrl(params)
        ? await launchUrlMedito(href)
        : throw 'Could not launch $href';
  }

  return true;
}

Future<void> launchEmailSubmission(
  String href, {
  String? subject,
  String? body,
}) async {
  var query = '';
  if (subject != null) {
    query = 'subject=$subject';
  }
  if (body != null) {
    var _body = body.replaceAll('\n', '\r\n');
    query = query != '' ? '$query&body=$_body' : 'body=$_body';
  }

  final params = Uri(
    scheme: 'mailto',
    path: href.replaceAll('mailto:', ''),
    query: query,
  );

  if (await canLaunchUrl(params)) {
    await launchUrl(params);
  } else {
    var url = params.toString();
    print('Could not launch $url');
  }
}

int convertDurationToMinutes({required int milliseconds}) {
  return Duration(milliseconds: milliseconds).inMinutes;
}

//ignore: prefer-match-file-name
extension EmptyOrNull on String? {
  bool isNullOrEmpty() {
    if (this == null) return true;
    if (this?.isEmpty == true) return true;

    return false;
  }

  bool isNotNullAndNotEmpty() {
    return this != null && this?.isNotEmpty == true;
  }
}

String getAudioFileExtension(String path) {
  var lastIndex = path.lastIndexOf('/');
  if (lastIndex != -1) {
    var filenameWithQuery = path.substring(lastIndex + 1);
    var filename = Uri.decodeFull(filenameWithQuery.split('?').first);
    var dotIndex = filename.lastIndexOf('.');
    if (dotIndex != -1) {
      var fileExtension = filename.substring(dotIndex + 1);

      return '.$fileExtension';
    }
  }

  return '.mp3';
}

Future<File?> capturePng(BuildContext context, GlobalKey globalKey) async {
  try {
    var pixelRatio = MediaQuery.of(context).devicePixelRatio;
    var boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    var image = await boundary.toImage(pixelRatio: pixelRatio);
    var byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    var pngBytes = byteData?.buffer.asUint8List();

    if (pngBytes != null) {
      var imgImage = img.decodeImage(Uint8List.fromList(pngBytes))!;
      var exportedPng = img.encodePng(imgImage);

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/stats.png');

      return await file.writeAsBytes(exportedPng);
    }

    return null;
  } catch (e) {
    rethrow;
  }
}

double getBottomPadding(BuildContext context) {
  var systemGestureInsets = MediaQuery.of(context).systemGestureInsets;
  var bottom = 32.0;
  bottom = systemGestureInsets.bottom > 32 ? systemGestureInsets.bottom : 16;

  return bottom;
}

int formatIcon(String icon) {
  return int.parse('0x$icon');
}

extension SanitisePath on String {
  String sanitisePath() {
    return replaceFirst('/', '');
  }
}

extension GetIdFromPath on String {
  String getIdFromPath() {
    return split('/').last;
  }
}
