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
import 'dart:ui' as ui;

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/widgets/pill_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildAttributionsAndDownloadButtonView(
    BuildContext context,
    String downloadURL,
    var contentText,
    var licenseTitle,
    var sourceUrl,
    var licenseName,
    String licenseURL,
    bool showDownloadButton) {
  return Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(bottom: 8, top: 24),
                  child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: getEdgeInsets(1, 1),
                        decoration: getBoxDecoration(1, 1,
                            color: MeditoColors.darkBGColor),
                        child: getTextLabel("← Go back", 1, 1, context),
                      )),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          color: MeditoColors.darkBGColor,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(
                              top: 20, bottom: 16.0, left: 16, right: 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                contentText,
                                style: Theme.of(context).textTheme.display3,
                              ),
                              getAttrWidget(context, licenseTitle, sourceUrl,
                                  licenseName, licenseURL),
                              (showDownloadButton != null && showDownloadButton)
                                  ? _buildDownloadButton(context, downloadURL)
                                  : Container(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Container getAttrWidget(BuildContext context, licenseTitle, sourceUrl,
    licenseName, String licenseURL) {
  return Container(
    padding: EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
    child: new RichText(
      textAlign: TextAlign.center,
      text: new TextSpan(
        children: [
          new TextSpan(
            text: 'From '.toUpperCase(),
            style: Theme.of(context).textTheme.display4,
          ),
          new TextSpan(
            text: licenseTitle?.toUpperCase(),
            style: Theme.of(context).textTheme.body2,
            recognizer: new TapGestureRecognizer()
              ..onTap = () {
                launch(sourceUrl);
              },
          ),
          new TextSpan(
            text: ' / License: '.toUpperCase(),
            style: Theme.of(context).textTheme.display4,
          ),
          new TextSpan(
            text: licenseName?.toUpperCase(),
            style: Theme.of(context).textTheme.body2,
            recognizer: new TapGestureRecognizer()
              ..onTap = () {
                launch(licenseURL);
              },
          ),
        ],
      ),
    ),
  );
}

Widget _buildDownloadButton(BuildContext context, String url) {
  return FlatButton.icon(
    color: MeditoColors.darkColor,
    onPressed: () => _launchDownload(url),
    icon: Icon(
      Icons.cloud_download,
      color: MeditoColors.lightColor,
    ),
    label: Text(
      'DOWNLOAD',
      style: Theme.of(context).textTheme.display2,
    ),
  );
}

_launchDownload(String url) {
  Tracking.trackEvent(Tracking.PLAYER, Tracking.AUDIO_DOWNLOAD, url);
  launch(url.replaceAll(' ', '%20'));
}

Future<dynamic> downloadFile(String url, String filename) async {
  String dir = (await getApplicationDocumentsDirectory()).path;
  File file = new File('$dir/$filename.mp3');
  var request = await http.get(
    url,
  );
  var bytes = request.bodyBytes;
  await file.writeAsBytes(bytes);
  print(file.path);
}

Future<dynamic> getDownload(String filename) async {
  var path = (await getApplicationDocumentsDirectory()).path;
  File file = new File('$path/$filename.mp3');
  if (await file.exists())
    return file.absolute.path;
  else
    return null;
}

/// Generates a 200x200 png, with randomized colors, to use as art for the
/// notification/lockscreen.
Future<Uint8List> generateImageBytes() async {
// Random color generation methods: pick contrasting hues.
  final HSLColor bgHslColor = HSLColor.fromColor(MeditoColors.darkBGColor);
  final HSLColor fgHslColor = HSLColor.fromColor(MeditoColors.lightColor);

  final Size size = const Size(200.0, 200.0);
  final Offset center = const Offset(100.0, 100.0);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Rect rect = Offset.zero & size;
  final Canvas canvas = Canvas(recorder, rect);
  final Paint bgPaint = Paint()
    ..style = PaintingStyle.fill
    ..color = bgHslColor.toColor();
  final Paint fgPaint = Paint()
    ..style = PaintingStyle.stroke
    ..color = bgHslColor.toColor()
    ..strokeWidth = 8;
// Draw background color.
  canvas.drawRect(rect, bgPaint);
// Draw 5 inset squares around the center.
  canvas.drawRect(
      Rect.fromCenter(center: center, width: 40.0, height: 40.0), fgPaint);
// Render to image, then compress to PNG ByteData, then return as Uint8List.
  final ui.Image image = await recorder
      .endRecording()
      .toImage(size.width.toInt(), size.height.toInt());
  final ByteData encodedImageData =
      await image.toByteData(format: ui.ImageByteFormat.png);
  return encodedImageData.buffer.asUint8List();
}
