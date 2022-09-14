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

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

const TILES_ID = 'tiles';
const AUDIO_SET = 'audio-set';
const AUDIO_DATA = 'audio-data';
const ATTRIBUTIONS = 'attrs';
const TEXT = 'text';

Future<void> clearStorage() async {
  if(!kIsWeb) {
    final cacheDir = await getApplicationDocumentsDirectory();

    await cacheDir.list(recursive: true).forEach((element) {
      print(element.path);
      try {
        if (element.path.endsWith('txt') || element.path.endsWith('mp3')) {
          element.deleteSync(recursive: true);
        }
      } catch (e) {
        print(e);
      }
    });
  }
}

Future<String> get _localPath async {
  if(kIsWeb) return '';
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> _localFile(String name) async {
  final path = await _localPath;
  return File('$path/$name.txt');
}

Future<String?> _readCache(String id) async {
  id = id.replaceAll('/', '+');

  final file = await _localFile(id);

  var lastModified;
  try {
    lastModified = await file.lastModified();
  } on FileSystemException {
    return null;
  }

  if (lastModified.add(Duration(days: 1)).isBefore(DateTime.now())) return null;

  // Read the file.
  return await file.readAsString();
}

String? encoded(dynamic obj) {
  if (obj != null) {
    return json.encode(obj);
  } else {
    return null;
  }
}

dynamic decoded(String obj) {
  return json.decode(obj);
}

Future<File?> writeJSONToCache(String? body, String id) async {
  if (body != null) {
    id = id.replaceAll('/', '+');
    final file = await _localFile(id);

    return file.writeAsString('$body');
  }
  return null;
}

Future<String?> readJSONFromCache(String url) async {
  try {
    return await _readCache(url);
  } catch (e) {
    return null;
  }
}
