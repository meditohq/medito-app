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

import 'package:Medito/network/auth.dart';
import 'package:Medito/network/cache.dart';
import 'package:Medito/utils/utils.dart';
import 'package:http/http.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

//move this to network package later
Future<Map<String, dynamic>?> httpGet(String url,
    {bool skipCache = false, String? fileNameForCache}) async {
  var cache;

  if (!await checkConnectivity()) {
    skipCache = false;
  }

  if (skipCache) {
    cache = null;
  } else {
    cache = await readJSONFromCache(fileNameForCache ?? url);
  }

  var auth = CONTENT_TOKEN;
  assert(auth.isNotEmpty);

  if (cache == null) {
    final response = await get(
      Uri.parse(url),
      headers: {
        HttpHeaders.authorizationHeader: auth,
        HttpHeaders.accessControlAllowOriginHeader: '*',
        HttpHeaders.accessControlAllowHeadersHeader: 'Origin,Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,locale',
        HttpHeaders.accessControlAllowCredentialsHeader: 'true',
        HttpHeaders.accessControlAllowMethodsHeader: 'POST, OPTIONS, HEAD, GET',
        HttpHeaders.contentTypeHeader: ContentType.json.value,
        HttpHeaders.refererHeader: 'no-referrer-when-downgrade',
        HttpHeaders.acceptHeader: '*/*'
      },
    );

    if (response.statusCode == 200) {
      await writeJSONToCache(response.body, fileNameForCache ?? url);
    } else {
      unawaited(Sentry.captureMessage(
          'response code: ${response.statusCode}, url: $url, headers: ${response.headers} reason: ${response.reasonPhrase}'));
      print('----GET----');
      print('CACHE USED: ${cache != null}');
      print('FILE NAME FOR CACHE: ${fileNameForCache ?? ''}');
      print('AUTH: $auth');
      print('URL: $url');
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');
      print('REASON PHRASE: ${response.reasonPhrase}');
      print('HEADERS: ${response.headers}');
      print('---------');
    }

    try {
      var decode = json.decode(response.body);
      return decode;
    } catch (e, str) {
      unawaited(Sentry.captureException(e,
          stackTrace: str, hint: 'decode: ${response.body}'));
      return null;
    }
  }
  return json.decode(cache);
}

Future httpPost(String url, String token,
    {dynamic body = const <String, String>{}}) async {
  assert(token.isNotEmpty);
  try {
    final response = await post(
      Uri.parse(url),
      body: encoded(body),
      headers: {
        HttpHeaders.authorizationHeader: token,
        HttpHeaders.contentTypeHeader: 'application/json'
      },
    );
    if (response.statusCode == 200) {
      return response.body.isNotEmpty ? json.decode(response.body) : true;
    } else {
      print('----POST-----');
      print('AUTH: $token');
      print('URL: $url');
      print('STATUS: ${response.statusCode}');
      print('BODY: ${response.body}');
      print('REASON PHRASE: ${response.reasonPhrase}');
      print('HEADERS: ${response.headers}');
      print('---------');
    }
  } catch (e) {
    print(e);
    return null;
  }
}
