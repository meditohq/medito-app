import 'package:Medito/network/http_get.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth.dart';
import 'new_folder_response.dart';
part 'folder_provider.g.dart';

var folderParameters =
    '?fields=*,items.item:folders.id,items.item:folders.type,items.item:folders.title,items.item:folders.subtitle,items.item:sessions.id,items.item:sessions.type,items.item:sessions.title,items.item:sessions.subtitle,items.item:dailies.id,items.item:dailies.type,items.item:dailies.title,items.item:dailies.subtitle,items.item:articles.id,items.item:articles.type,items.item:articles.title,items.item:articles.subtitle&deep[items][_sort]=position';
var ext = 'items/folders/';

@riverpod
Future<NewFolderResponse?> folderData(
  FolderDataRef _, {
  String? id,
  bool skipCache = false,
}) async {
  if (id == null) {
    throw Exception('Folder ID is null!');
  }

  final content = await _httpGet(id, skipCache);

  if (content == null) return null;

  return NewFolderResponse.fromJson(content);
}

Future<Map<String, Object?>?> _httpGet(String id, bool skipCache) {
  return httpGet(
    BASE_URL + ext + id + folderParameters,
    fileNameForCache: BASE_URL + id + '/' + ext,
    skipCache: skipCache,
  );
}
