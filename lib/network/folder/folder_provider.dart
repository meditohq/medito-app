import 'package:Medito/network/http_get.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth.dart';
import 'new_folder_response.dart';

var folderParameters =
    '?fields=*,items.item:folders.id,items.item:folders.type,items.item:folders.title,items.item:folders.subtitle,items.item:sessions.id,items.item:sessions.type,items.item:sessions.title,items.item:sessions.subtitle,items.item:dailies.id,items.item:dailies.type,items.item:dailies.title,items.item:dailies.subtitle,items.item:articles.id,items.item:articles.type,items.item:articles.title,items.item:articles.subtitle&deep[items][_sort]=position';
var ext = 'items/folders/';

final folderProvider =
    FutureProvider.family<NewFolderResponse?, String?>((ref, id) async {
  if (id == null) {
    throw Exception('Id is null');
  }
  final skipCache = ref.watch(folderSkipCacheProvider);
  final content = await _httpGet(id, skipCache);

  if(content == null) return null;
  return NewFolderResponse.fromJson(content);
});

final folderProviderSkipCache =
    FutureProvider.family<NewFolderResponse?, String>((ref, id) async {
  final content = await _httpGet(id, true);

  if(content == null) return null;

  return NewFolderResponse.fromJson(content);
});

Future<Map<String,Object?>?> _httpGet(String id, bool skipCache) {
  return httpGet(
    BASE_URL + ext + id + folderParameters,
    fileNameForCache: BASE_URL + id + '/' + ext,
    skipCache: skipCache,
  );
}

final folderSkipCacheProvider = StateProvider<bool>((ref) => false);
