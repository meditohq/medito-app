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

import 'package:Medito/data/attributions.dart';
import 'package:Medito/data/page.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'download_class.dart';

var downloadListener = ValueNotifier<double>(0);
var bgDownloadListener = ValueNotifier<double>(0);
var baseUrl = 'https://medito.space/api/pages';
int bgTotal = 1, bgReceived = 0;
var backgroundMusicUrl = '';

bool bgDownloading = false, removing = false;

DownloadSingleton downloadSingleton;

Container getAttrWidget(BuildContext context, licenseTitle, sourceUrl,
    licenseName, String licenseURL) {
  return Container(
    padding: EdgeInsets.only(top: 16, bottom: 8, left: 16, right: 16),
    child: RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        children: [
          // ignore: unnecessary_new
          new TextSpan(
            text: 'From ',
            style: Theme.of(context).textTheme.headline1,
          ),
          TextSpan(
            text: licenseTitle ?? '',
            style: Theme.of(context).textTheme.bodyText1,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launch(sourceUrl);
              },
          ),
          TextSpan(
            text: ' / License: ',
            style: Theme.of(context).textTheme.headline1,
          ),
          TextSpan(
            text: licenseName ?? '',
            style: Theme.of(context).textTheme.bodyText1,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                launch(licenseURL);
              },
          ),
        ],
      ),
    ),
  );
}

Future<dynamic> checkFileExists(Files currentFile) async {
  var dir = (await getApplicationSupportDirectory()).path;
  var name = currentFile.filename.replaceAll(' ', '%20');
  var file = File('$dir/$name');
  var exists = await file.exists();
  return exists;
}

Future getAttributions(String attrId) async {
  var baseUrl = 'https://medito.space/api/pages';
  var url = baseUrl + '/' + attrId.replaceAll('/', '+');
  var response = await httpGet(url);
  var attrs = Attributions.fromJson(response);

  return attrs.data.content;
}

Future<dynamic> downloadBGMusicFromURL(String url, String name) async {
  var dir = (await getApplicationSupportDirectory()).path;
  name = name.replaceAll(' ', '%20');
  var file = File('$dir/$name');

  if (await file.exists()) return file.path;

  var request = await http.get(url);
  var bytes = request.bodyBytes;
  await file.writeAsBytes(bytes);

  return file.path;
}

Future<dynamic> downloadBGMusicFromURLWithProgress(
    String url, String name) async {
  var dir = (await getApplicationSupportDirectory()).path;
  name = name.replaceAll(' ', '%20');
  var file = File('$dir/$name');

  if (await file.exists()) {
    backgroundMusicUrl = file.path;
    return file.path;
  }
  var _response = await http.Client().send(http.Request('GET', Uri.parse(url)));
  bgTotal = _response.contentLength;
  bgReceived = 0;
  var _bytes = <int>[];

  _response.stream.listen((value) {
    _bytes.addAll(value);
    bgReceived += value.length;
    //print("File Progress New: " + getProgress().toString());
    bgDownloadListener.value = bgReceived * 1.0 / bgTotal;
  }).onDone(() async {
    await file.writeAsBytes(_bytes);
    print('Saved BG New: ' + file.path);
    bgDownloading = false;
    backgroundMusicUrl = file.path;
  });
}

Future<void> saveFileToDownloadedFilesList(Files file) async {
  var prefs = await SharedPreferences.getInstance();
  var list = prefs.getStringList('listOfSavedFiles') ?? [];
  list.add(file?.toJson()?.toString() ?? '');
  await prefs.setStringList('listOfSavedFiles', list);
}

Future<void> removeFileFromDownloadedFilesList(Files file) async {
  var prefs = await SharedPreferences.getInstance();
  var list = prefs.getStringList('listOfSavedFiles') ?? [];
  list.remove(file?.toJson()?.toString() ?? '');
  await prefs.setStringList('listOfSavedFiles', list);
}

Future<dynamic> removeFile(Files currentFile) async {
  await getAttributions(currentFile.attributions);
  var dir = (await getApplicationSupportDirectory()).path;
  var name = currentFile.filename.replaceAll(' ', '%20');
  var file = File('$dir/$name');

  if (await file.exists()) {
    await file.delete();
    await removeFileFromDownloadedFilesList(currentFile);
    removing = false;
  } else {
    removing = false;
  }
}

Future<dynamic> downloadFile(Files currentFile) async {
  await getAttributions(currentFile.attributions);

  var dir = (await getApplicationSupportDirectory()).path;
  var name = currentFile.filename.replaceAll(' ', '%20');
  var file = File('$dir/$name');

  if (await file.exists()) return null;

  var request = await http.get(currentFile.url);
  if (request.statusCode < 200 || request.statusCode > 300) {
    throw HttpException('http exception error getting file');
  }
  var bytes = request.bodyBytes;
  await file.writeAsBytes(bytes);

  await saveFileToDownloadedFilesList(currentFile);

  print(file.path);
}

Future<dynamic> getDownload(String filename) async {
  var path = (await getApplicationSupportDirectory()).path;
  filename = filename.replaceAll(' ', '%20');
  var file = File('$path/$filename');
  if (await file.exists()) {
    return file.absolute.path;
  } else {
    return null;
  }
}
