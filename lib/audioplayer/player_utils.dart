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

import 'package:Medito/network/session_options/session_opts.dart';
import 'package:Medito/user/user_utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

var downloadListener = ValueNotifier<double>(0);
var bgDownloadListener = ValueNotifier<double>(0);
int bgTotal = 1, bgReceived = 0;

Future<dynamic> checkFileExists(AudioFile currentFile) async {
  var filePath = (await getFilePath(currentFile.id));
  var file = File(filePath);
  var exists = await file.exists();
  return exists;
}

Future<dynamic> checkBgSoundExists(String name) async {
  var filePath = (await getFilePath(name));
  var file = File(filePath);
  var exists = await file.exists();
  return exists;
}

Future<dynamic> downloadBGMusicFromURL(String id, String name) async {
  var path = (await getFilePath(name));
  var file = File(path);
  if (await file.exists()) return file.path;

  var url = '${baseUrl}assets/$id';
  var request = await http.get(url, headers: {HttpHeaders.authorizationHeader: await token});
  var bytes = request.bodyBytes;
  await file.writeAsBytes(bytes);

  return file.path;
}

Future<String> getFilePath(String mediaItemId) async {
  var dir = (await getApplicationSupportDirectory()).path;
  return '$dir/${mediaItemId.replaceAll('/', '_').replaceAll(' ', '_')}.mp3';
}

Future<dynamic> getDownload(String filename) async {
  var path = (await getFilePath(filename));
  var file = File(path);
  if (await file.exists()) {
    return file.path;
  } else {
    return null;
  }
}
