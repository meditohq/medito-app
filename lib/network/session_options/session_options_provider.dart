import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth.dart';

part 'session_options_provider.g.dart';

var ext = 'items/sessions/';
var dailiesExt = 'items/dailies/';
var parameters =
    '?fields=*,author.body,audio.file.id,audio.file.voice,audio.file.length';
var screen;

@riverpod
Future<SessionOptionsResponse?> sessionOptionsData(ref,
    {String? id, bool skipCache = false, bool isDaily = false}) async {
  if (id == null) {
    throw Exception('Folder ID is null!');
  }

  final content = await _httpGet(id, skipCache, isDaily);

  if (content == null) return null;
  return SessionOptionsResponse.fromJson(content);
}

Future<Map<String, Object?>?> _httpGet(
    String id, bool skipCache, bool isDaily) {
  if (isDaily) {
    return httpGet(
      BASE_URL + dailiesExt + id + parameters,
      fileNameForCache: BASE_URL + id + '/' + ext,
      skipCache: skipCache,
    );
  } else {
    return httpGet(
      BASE_URL + ext + id + parameters,
      fileNameForCache: BASE_URL + id + '/' + ext,
      skipCache: skipCache,
    );
  }
}
