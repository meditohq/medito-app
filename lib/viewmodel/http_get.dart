import 'dart:convert';
import 'dart:io';

import 'package:Medito/utils/utils.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'cache.dart';

Future httpGet(String url, {bool skipCache = false}) async {
  var cache;

  if (!await checkConnectivity()) {
    skipCache = false;
  }

  if (skipCache) {
    cache = null;
  } else {
    cache = await readJSONFromCache(url);
  }

  if (cache == null) {
    final response = await http.get(
      url,
      headers: {HttpHeaders.authorizationHeader: basicAuth},
    );

    if (!response.body.contains('error')) {
      await writeJSONToCache(response.body, url);
    }
    return json.decode(response.body);
  }
  return json.decode(cache);
}
