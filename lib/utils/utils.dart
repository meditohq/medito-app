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

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Medito/constants/constants.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> checkConnectivity() async {
  var connectivityResult = await Connectivity().checkConnectivity();

  return connectivityResult != ConnectivityResult.none;
}

Color parseColor(String? color) {
  if (color == null || color.isEmpty) return ColorConstants.ebony;

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

Future<void> launchURLInBrowser(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      var launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
      }
    }
  } catch (e, stackTrace) {
    await Sentry.captureException(
      e,
      stackTrace: stackTrace,
    );
  }
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
}

double getBottomPadding(BuildContext context) {
  var systemGestureInsets = MediaQuery.of(context).systemGestureInsets;
  var bottom =
      systemGestureInsets.bottom > 32 ? systemGestureInsets.bottom : 20.0;

  return bottom;
}

double getBottomPaddingWithStickyMiniPlayer(BuildContext context) {
  var navbarPadding = getBottomPadding(context);
  var bottomPadding = 8;
  var totalPadding = navbarPadding + miniPlayerHeight + bottomPadding;

  return totalPadding;
}

Future<String> getFilePathForOldAppDownloadedFiles(String mediaItemId) async {
  var dir = (await getApplicationSupportDirectory()).path;

  return '$dir/${mediaItemId.replaceAll('/', '_').replaceAll(' ', '_')}.mp3';
}

int formatIcon(String icon) {
  return int.parse('0x$icon');
}

Future<bool> checkGooglePlayServices() async {
  try {
    if (Platform.isIOS) {
      return true;
    } else if (Platform.isAndroid) {
      var availability = await GoogleApiAvailability.instance
          .checkGooglePlayServicesAvailability();
      if (availability == GooglePlayServicesAvailability.success) {
        return true;
      }
    }

    return false;
  } catch (e) {
    unawaited(Sentry.captureException(
      e,
      stackTrace: e,
    ));

    return false;
  }
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
