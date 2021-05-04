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

import 'package:Medito/user/user_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/viewmodel/auth.dart';
import 'package:Medito/viewmodel/cache.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';


//move this to network package later
Future httpGet(String url,
    {bool skipCache = false, String fileNameForCache}) async {
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
  assert(auth != null);

  if (cache == null) {
    final response = await get(
      Uri.parse(url),
      headers: {HttpHeaders.authorizationHeader: auth},
    );

    if (response.statusCode == 200) {
      await writeJSONToCache(response.body, fileNameForCache ?? url);
    } else {
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
    return json.decode(response.body);
  }
  return json.decode(cache);
}

Future httpPost(String url, String token, {dynamic body = const <String, String>{}}) async {
  assert(token.isNotEmpty);
  assert(token != null);
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
