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

import 'package:Medito/network/sessionoptions/session_opts.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

var downloadListener = ValueNotifier<double>(0);
var bgDownloadListener = ValueNotifier<double>(0);
int bgTotal = 1, bgReceived = 0;
var backgroundMusicUrl = '';

Future<dynamic> checkFileExists(AudioFile currentFile) async {
  var dir = (await getApplicationSupportDirectory()).path;
  var name = currentFile.id;
  var file = File('$dir/$name');
  var exists = await file.exists();
  return exists;
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
