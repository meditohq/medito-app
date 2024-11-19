import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:medito/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Color parseColor(String? color) {
  if (color == null || color.isEmpty) return ColorConstants.ebony;
  try {
    return Color(int.parse(color.replaceFirst('#', 'FF'), radix: 16));
  } catch (e) {
    return ColorConstants.ebony;
  }
}

void createSnackBar(
  String message,
  BuildContext context, {
  Color color = Colors.red,
}) {
  final snackBar = SnackBar(
    content: Text(message),
    backgroundColor: color,
    duration: const Duration(seconds: 6),
  );

  try {
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  } catch (e) {
    print(e);
  }
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
  } catch (e) {
    if (kDebugMode) {
        print(e);
      }
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
    var newBody = body.replaceAll('\n', '\r\n');
    query = query != '' ? '$query&body=$newBody' : 'body=$newBody';
  }

  final params = Uri(
    scheme: 'mailto',
    path: href.replaceAll('mailto:', ''),
    query: query,
  );

  if (await canLaunchUrl(params)) {
    await launchUrl(params);
  }
}

int convertDurationToMinutes({required int milliseconds}) {
  const millisecondsPerMinute = 60000;

  return (milliseconds.abs() / millisecondsPerMinute).round();
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
    // Add a small delay to ensure widget has updated
    await Future.delayed(const Duration(milliseconds: 100));
    
    RenderRepaintBoundary boundary =
        globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    final directory = await getApplicationDocumentsDirectory();
    final appDir = Directory('${directory.path}/medito');
    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }
    final file = File('${appDir.path}/stats.png');

    await file.writeAsBytes(pngBytes);
    if (kDebugMode) {
      print('File saved at: ${file.path}');
    }

    return file;
  } catch (e) {
    if (kDebugMode) {
      print('Error in capturePng: $e');
    }
    return null;
  }
}

int formatIcon(String icon) {
  if (icon.isEmpty) return 0;

  return int.parse('0x$icon');
}

extension GetIdFromPath on String {
  String getIdFromPath() {
    return split('/').last;
  }
}
