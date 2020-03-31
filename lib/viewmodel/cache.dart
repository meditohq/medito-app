import 'dart:io';

import 'package:path_provider/path_provider.dart';

const TILES_ID = 'tiles';
const AUDIO_SET = 'audio-set';
const AUDIO_DATA = 'audio-data';
const ATTRIBUTIONS = 'attrs';
const TEXT = 'text';

Future<String> get _localPath async {
  final directory = await getApplicationDocumentsDirectory();
  return directory.path;
}

Future<File> _localFile(String name) async {
  final path = await _localPath;
  return File('$path/$name.txt');
}

Future<String> _readCache(String id) async {
  id = id.replaceAll('/', '+');

  final file = await _localFile(id);

  var lastModified;
  try {
    lastModified = await file?.lastModified();
  } on FileSystemException {
    return null;
  }

  if (lastModified.add(Duration(days: 1)).isBefore(DateTime.now())) return null;

  // Read the file.
  return await file.readAsString();
}

Future<File> writeJSONToCache(String body, String id) async {
  id = id.replaceAll('/', '+');
  final file = await _localFile(id);

  return file.writeAsString('$body');
}

Future<String> readJSONFromCache(String url) async {
  try {
    return await _readCache(url);
  } catch (e) {
    return null;
  }
}
