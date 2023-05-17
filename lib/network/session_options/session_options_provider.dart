import 'package:Medito/constants/constants.dart';
import 'package:Medito/network/http_get.dart';
import 'package:Medito/network/session_options/session_opts.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'session_options_provider.g.dart';

var ext = 'items/sessions/';
var dailiesExt = 'items/dailies/';
var parameters =
    '?fields=*,author.body,audio.file.id,audio.file.voice,audio.file.length';
var screen;

@riverpod
Future<SessionOptionsResponse?> sessionOptionsData(
  _, {
  String? id,
  bool skipCache = false,
  bool isDaily = false,
}) async {
  if (id == null) {
    throw Exception('Folder ID is null!');
  }

  final content = await _httpGet(id, skipCache, isDaily);

  if (content == null) return null;

  return SessionOptionsResponse.fromJson(content);
}

Future<Map<String, Object?>?> _httpGet(
  String id,
  bool skipCache,
  bool isDaily,
) {
  return isDaily
      ? httpGet(
          HTTPConstants.BASE_URL_OLD + dailiesExt + id + parameters,
          fileNameForCache: HTTPConstants.BASE_URL_OLD + id + '/' + ext,
          skipCache: skipCache,
        )
      : httpGet(
          HTTPConstants.BASE_URL_OLD + ext + id + parameters,
          fileNameForCache: HTTPConstants.BASE_URL_OLD + id + '/' + ext,
          skipCache: skipCache,
        );
}
